# E-commerce API Backend

This is the backend API for the ShopSmart e-commerce platform.

## Setup Instructions

### Environment Setup

1. **Create .env file**:
   - Copy the `.env.example` file to a new file named `.env`
   - Update the values in the `.env` file with your actual configuration

```bash
cp .env.example .env
# Edit .env file with your preferred editor
```

2. **Database Configuration**:
   Configure these PostgreSQL settings in your `.env` file:

   ```
   DB_HOST=localhost          # PostgreSQL server address
   DB_NAME=ecommerce          # Database name
   DB_USER=postgres           # Database username
   DB_PASSWORD=your_password  # Database password
   DB_PORT=5432               # PostgreSQL port
   ```

3. **API Configuration**:
   Configure API server settings in your `.env` file:

   ```
   API_HOST=0.0.0.0    # API binding address (0.0.0.0 to listen on all interfaces)
   API_PORT=8000       # API port number
   DEBUG=False         # Set to True for development mode
   ```

### Installing Dependencies

1. Create a virtual environment:
   ```bash
   python -m venv venv
   ```

2. Activate the virtual environment:
   - Windows: `venv\Scripts\activate`
   - Linux/Mac: `source venv/bin/activate`

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

### Running the Application

Start the application with:

```bash
python main.py
```

Or using uvicorn directly:

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

The API will be available at: http://localhost:8000

API documentation will be available at: http://localhost:8000/docs

## PostgreSQL Setup

If you need to set up PostgreSQL:

1. Install PostgreSQL:
   - [Download PostgreSQL](https://www.postgresql.org/download/)
   - Follow the installation instructions

2. Create a database:
   ```sql
   CREATE DATABASE ecommerce;
   ```

3. Create a user (optional):
   ```sql
   CREATE USER myuser WITH ENCRYPTED PASSWORD 'mypassword';
   GRANT ALL PRIVILEGES ON DATABASE ecommerce TO myuser;
   ```

4. Update your .env file with these credentials 