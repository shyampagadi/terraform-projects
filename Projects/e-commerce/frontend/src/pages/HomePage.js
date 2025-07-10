import React from 'react';
import { Link } from 'react-router-dom';

const HomePage = () => {
  return (
    <div className="home-page">
      <h1>Welcome to E-Commerce App</h1>
      <Link to="/products" className="btn btn-primary">
        Browse Products
      </Link>
    </div>
  );
};

export default HomePage;