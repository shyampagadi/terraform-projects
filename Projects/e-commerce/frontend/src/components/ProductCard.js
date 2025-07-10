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

  // Calculate random rating for demo purposes
  const rating = ((Math.random() * 2) + 3).toFixed(1); // Random rating between 3.0 and 5.0
  const reviewCount = Math.floor(Math.random() * 100) + 5; // Random review count
  
  // Random discount for some products (demo only)
  const hasDiscount = Math.random() > 0.7;
  const discountPercent = hasDiscount ? Math.floor(Math.random() * 30) + 10 : 0; // 10-40% discount
  const originalPrice = product.price || 0;
  const discountedPrice = hasDiscount 
    ? (originalPrice * (1 - discountPercent / 100)).toFixed(2) 
    : null;
  
  // Random "New" badge for some products (demo only)
  const isNew = !hasDiscount && Math.random() > 0.8;
  
  return (
    <div className="product-card card-hover">
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
          <div className="image-placeholder">No Image Available</div>
        )}
        
        {hasDiscount && (
          <div className="discount-badge">-{discountPercent}%</div>
        )}
        
        {isNew && (
          <div className="new-badge">New</div>
        )}
        
        <div className="quick-actions">
          <button className="quick-action-btn" aria-label="Add to favorites">
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78L12 21.23l8.84-8.84a5.5 5.5 0 0 0 0-7.78z"></path>
            </svg>
          </button>
          <button className="quick-action-btn" aria-label="Add to cart">
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <circle cx="9" cy="21" r="1"></circle>
              <circle cx="20" cy="21" r="1"></circle>
              <path d="M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6"></path>
            </svg>
          </button>
        </div>
      </div>
      
      <div className="product-details">
        <div className="product-category">{product.category || 'Uncategorized'}</div>
        <h3 className="product-name">{product.name || 'Untitled Product'}</h3>
        
        <div className="rating">
          {[1, 2, 3, 4, 5].map((star) => (
            <span key={star} className="star">
              {star <= Math.floor(rating) ? (
                <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="currentColor" stroke="none">
                  <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2" />
                </svg>
              ) : star - Math.floor(rating) < 1 && star - Math.floor(rating) > 0 ? (
                <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="currentColor" stroke="none">
                  <path d="M12 2 L15.09 8.26 L22 9.27 L17 14.14 L18.18 21.02 L12 17.77 L12 2 Z" />
                  <path d="M12 17.77 L5.82 21.02 L7 14.14 L2 9.27 L8.91 8.26 L12 2 L12 17.77 Z" fill="none" stroke="currentColor" strokeWidth="1.5" />
                </svg>
              ) : (
                <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
                  <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2" />
                </svg>
              )}
            </span>
          ))}
          <span className="count">({reviewCount})</span>
        </div>
        
        <div className="product-price">
          {hasDiscount && (
            <>
              <span>${discountedPrice}</span>
              <span className="original-price">${originalPrice.toFixed(2)}</span>
            </>
          )}
          {!hasDiscount && (
            <span>${product.price ? product.price.toFixed(2) : '0.00'}</span>
          )}
        </div>
        
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