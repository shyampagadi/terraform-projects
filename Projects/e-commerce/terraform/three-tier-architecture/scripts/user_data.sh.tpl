#!/bin/bash
set -e

# Update the system
yum update -y

# Install necessary packages
yum install -y httpd amazon-cloudwatch-agent amazon-ssm-agent docker git

# Start and enable services
systemctl start httpd
systemctl enable httpd
systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start docker
systemctl enable docker

# Set up application directory
mkdir -p /app

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/bin/config.json << 'EOF'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "metrics": {
    "metrics_collected": {
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "resources": [
          "/"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ]
      },
      "swap": {
        "measurement": [
          "swap_used_percent"
        ]
      }
    },
    "append_dimensions": {
      "AutoScalingGroupName": "${asg_name}",
      "InstanceId": "${!aws:InstanceId}",
      "InstanceType": "${!aws:InstanceType}"
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/httpd/access_log",
            "log_group_name": "${log_group}",
            "log_stream_name": "{instance_id}/apache/access",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/httpd/error_log",
            "log_group_name": "${log_group}",
            "log_stream_name": "{instance_id}/apache/error",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/messages",
            "log_group_name": "${log_group}",
            "log_stream_name": "{instance_id}/system/messages",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
EOF

# Start the CloudWatch agent
systemctl start amazon-cloudwatch-agent
systemctl enable amazon-cloudwatch-agent

# Deploy application
cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>E-Commerce Application</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            background: #f5f5f5;
        }
        .container {
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            text-align: center;
            max-width: 800px;
        }
        h1 {
            color: #333;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>E-Commerce Application</h1>
        <p>Environment: ${environment}</p>
        <p>Server ID: ${server_id}</p>
        <p>Version: ${app_version}</p>
        <p>Status: Running</p>
    </div>
</body>
</html>
EOF

# Create a health check endpoint
cat > /var/www/html/health << 'EOF'
OK
EOF

# Set proper permissions
chown -R apache:apache /var/www/html/

# Tag instance
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
aws ec2 create-tags --resources $INSTANCE_ID --tags Key=Name,Value=${name} --region ${region}

echo "Configuration completed" 