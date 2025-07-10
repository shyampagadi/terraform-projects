import React from 'react';
import { Link } from 'react-router-dom';
import '../styles/ProductCard.css';

const ProductCard = ({ product }) => {
  // Validate product structure
  if (!product || typeof product !== 'object') {
    console.error('Invalid product data:', product);
    return null;
  }
  
  // Validate required fields
  if (!product.id || typeof product.id !== 'number') {
    console.error('Product missing valid ID:', product);
    return null;
  }
  
  return (
    <div className="product-card">
      <div className="product-image">
        {product.image_url ? (
          <img 
            src={product.image_url} 
            alt={product.name} 
            onError={(e) => {
              e.target.onerror = null;
              e.target.parentNode.innerHTML = '<div class="image-placeholder">Image failed to load</div>';
            }}
          />
        ) : (
          <div className="image-placeholder">No Image</div>
        )}
      </div>
      <div className="product-details">
        <h3 className="product-name">{product.name || 'Untitled Product'}</h3>
        <p className="product-price">${product.price ? product.price.toFixed(2) : '0.00'}</p>
        <p className="product-category">{product.category || 'Uncategorized'}</p>
        <div className="product-actions">
          <Link 
            to={`/products/${product.id}`} 
            className="btn btn-primary"
          >
            View Details
          </Link>
          <Link 
            to={`/edit-product/${product.id}`} 
            className="btn btn-secondary"
          >
            Edit
          </Link>
        </div>
      </div>
    </div>
  );
};

export default ProductCard;