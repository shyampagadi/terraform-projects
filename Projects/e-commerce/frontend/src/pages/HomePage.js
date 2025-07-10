import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import ProductCard from '../components/ProductCard';
import productService from '../api/productService';
import Loader from '../components/Loader';

const HomePage = () => {
  const [featuredProducts, setFeaturedProducts] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    const fetchProducts = async () => {
      try {
        setIsLoading(true);
        setError('');
        
        const data = await productService.getAll();
        
        if (Array.isArray(data) && data.length > 0) {
          // Get up to 4 random products for featured section
          const randomProducts = data.sort(() => 0.5 - Math.random()).slice(0, 4);
          setFeaturedProducts(randomProducts);
        }
      } catch (err) {
        setError('Failed to load featured products');
        console.error('Error fetching products:', err);
      } finally {
        setIsLoading(false);
      }
    };

    fetchProducts();
  }, []);

  // Demo categories for homepage
  const categories = [
    { id: 1, name: 'Electronics', icon: '💻' },
    { id: 2, name: 'Clothing', icon: '👕' },
    { id: 3, name: 'Home & Kitchen', icon: '🏠' },
    { id: 4, name: 'Books', icon: '📚' },
    { id: 5, name: 'Sports', icon: '🏀' },
    { id: 6, name: 'Beauty', icon: '💄' }
  ];

  return (
    <div className="home-page">
      {/* Hero Section */}
      <section className="hero-section">
        <div className="hero-content">
          <h1>Welcome to ShopSmart</h1>
          <p>Discover amazing products at incredible prices</p>
          <Link to="/products" className="btn btn-primary btn-lg">
            Shop Now
          </Link>
        </div>
      </section>

      {/* Categories Section */}
      <section className="section">
        <div className="section-header">
          <h2>Browse Categories</h2>
          <Link to="/categories" className="view-all-link">View All</Link>
        </div>
        
        <div className="categories-grid">
          {categories.map(category => (
            <Link 
              to={`/products?category=${category.name}`} 
              className="category-card"
              key={category.id}
            >
              <div className="category-icon">{category.icon}</div>
              <h3>{category.name}</h3>
            </Link>
          ))}
        </div>
      </section>

      {/* Featured Products Section */}
      <section className="section">
        <div className="section-header">
          <h2>Featured Products</h2>
          <Link to="/products" className="view-all-link">View All</Link>
        </div>
        
        {isLoading ? (
          <Loader size="small" message="Loading featured products..." />
        ) : error ? (
          <div className="alert alert-error">{error}</div>
        ) : featuredProducts.length > 0 ? (
          <div className="product-grid">
            {featuredProducts.map(product => (
              <ProductCard key={product.id} product={product} />
            ))}
          </div>
        ) : (
          <div className="empty-state">
            <p>No products available at the moment</p>
            <Link to="/create-product" className="btn btn-primary">Add Product</Link>
          </div>
        )}
      </section>

      {/* Promotions Section */}
      <section className="promotions-section">
        <div className="promotion-card">
          <div className="promotion-content">
            <span className="promotion-label">Special Offer</span>
            <h3>Get 20% Off</h3>
            <p>On your first purchase when you sign up</p>
            <button className="btn btn-secondary">Learn More</button>
          </div>
        </div>
        
        <div className="promotion-card">
          <div className="promotion-content">
            <span className="promotion-label">New Collection</span>
            <h3>Summer 2023</h3>
            <p>Check out our latest arrivals</p>
            <button className="btn btn-secondary">Discover</button>
          </div>
        </div>
      </section>
      
      {/* Newsletter Section */}
      <section className="newsletter-section">
        <div className="newsletter-content">
          <h2>Join Our Newsletter</h2>
          <p>Sign up to receive updates on new products and special promotions</p>
          <form className="newsletter-form-inline">
            <input 
              type="email" 
              className="newsletter-input" 
              placeholder="Enter your email address"
              required
            />
            <button type="submit" className="btn btn-primary">Subscribe</button>
          </form>
        </div>
      </section>
    </div>
  );
};

export default HomePage;