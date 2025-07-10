// src/config/config.js
const env = process.env.REACT_APP_ENV || 'development';

const config = {
  development: {
    apiBaseUrl: 'http://localhost:8000',
    dbConfig: {
      host: process.env.REACT_APP_DB_HOST_DEV || 'localhost',
      name: process.env.REACT_APP_DB_NAME_DEV || 'ecommerce_dev'
    }
  },
  production: {
    apiBaseUrl: process.env.REACT_APP_API_BASE_URL || 'https://api.example.com',
    dbConfig: {
      host: process.env.REACT_APP_DB_HOST_PROD,
      name: process.env.REACT_APP_DB_NAME_PROD
    }
  }
};

export default config[env];