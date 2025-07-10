import React, { useState, useEffect } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import productService from '../api/productService';
import Loader from '../components/Loader';

const ProductDetailPage = () => {
  const { id } = useParams();
  const navigate = useNavigate();
  const [product, setProduct] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [debugInfo, setDebugInfo] = useState('');

  useEffect(() => {
    // Validate ID before fetching
    if (!id || isNaN(Number(id))) {
      setError('Invalid product ID');
      setDebugInfo(`Received invalid ID: ${id}`);
      setIsLoading(false);
      return;
    }

    const fetchProduct = async () => {
      try {
        setIsLoading(true);
        setError('');
        setDebugInfo(`Fetching product ID: ${id}`);
        
        const data = await productService.getById(id);
        
        // Validate product structure
        if (!data || typeof data !== 'object' || typeof data.id !== 'number') {
          setError('Invalid product data received');
          setDebugInfo(`Response data: ${JSON.stringify(data, null, 2)}`);
          return;
        }
        
        setProduct(data);
        setDebugInfo(`Successfully loaded product: ${data.name}`);
      } catch (err) {
        let errorMsg = 'Failed to load product details';
        
        if (err.response?.data?.detail) {
          if (Array.isArray(err.response.data.detail)) {
            errorMsg = err.response.data.detail.map(e => e.msg).join(', ');
          } else {
            errorMsg = err.response.data.detail;
          }
        } else if (err.message) {
          errorMsg = err.message;
        }
        
        setError(errorMsg);
        setDebugInfo(`Status: ${err.response?.status || 'N/A'} | URL: ${err.config?.url || 'N/A'}`);
        console.error('Product fetch error:', err);
      } finally {
        setIsLoading(false);
      }
    };

    fetchProduct();
  }, [id]);

  const handleDelete = async () => {
    if (window.confirm('Are you sure you want to delete this product?')) {
      try {
        await productService.delete(id);
        navigate('/products');
      } catch (err) {
        let errorMsg = 'Failed to delete product';
        
        if (err.response?.data?.detail) {
          if (Array.isArray(err.response.data.detail)) {
            errorMsg = err.response.data.detail.map(e => e.msg).join(', ');
          } else {
            errorMsg = err.response.data.detail;
          }
        } else if (err.message) {
          errorMsg = err.message;
        }
        
        setError(errorMsg);
      }
    }
  };

  if (isLoading) {
    return <Loader message={`Loading product ${id}...`} />;
  }

  return (
    <div className="product-detail-page">
      <h1 className="page-title">Product Details</h1>
      
      {error && (
        <div className="alert alert-error">
          <p>{error}</p>
          <p className="debug-info">{debugInfo}</p>
        </div>
      )}
      
      {product ? (
        <div className="product-detail">
          <div className="product-header">
            <h2>{product.name}</h2>
            <p className="price">${product.price.toFixed(2)}</p>
          </div>
          
          <div className="product-meta">
            <span className="category">{product.category || 'No category'}</span>
            <span className="product-id">ID: {product.id}</span>
          </div>
          
          <div className="product-description">
            <p>{product.description || 'No description available'}</p>
          </div>
          
          {product.image_url ? (
            <div className="product-image">
              <img 
                src={product.image_url} 
                alt={product.name} 
                onError={(e) => {
                  e.target.onerror = null;
                  e.target.parentNode.innerHTML = '<div class="image-placeholder">Image failed to load</div>';
                }}
              />
            </div>
          ) : (
            <div className="image-placeholder">No image available</div>
          )}
          
          <div className="product-actions">
            <Link 
              to={`/edit-product/${product.id}`} 
              className="btn btn-primary"
            >
              Edit Product
            </Link>
            <button 
              className="btn btn-danger"
              onClick={handleDelete}
            >
              Delete Product
            </button>
            <Link to="/products" className="btn btn-secondary">
              Back to Products
            </Link>
          </div>
        </div>
      ) : !error ? ( // Only show "not found" if there's no error
        <div className="empty-state">
          <p>Product not found (ID: {id})</p>
          <p className="debug-info">{debugInfo}</p>
          <Link to="/products" className="btn btn-primary">
            Browse Products
          </Link>
        </div>
      ) : null}
    </div>
  );
};

export default ProductDetailPage;