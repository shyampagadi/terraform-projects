import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import ProductCard from '../components/ProductCard';
import Loader from '../components/Loader';
import productService from '../api/productService';

const ProductListPage = () => {
  const [products, setProducts] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [debugInfo, setDebugInfo] = useState('');

  useEffect(() => {
    const fetchProducts = async () => {
      try {
        setIsLoading(true);
        setError('');
        setDebugInfo('Fetching products...');
        
        const data = await productService.getAll();
        
        // Validate response structure
        if (!Array.isArray(data)) {
          throw new Error('Invalid response format from API');
        }
        
        // Filter out invalid products
        const validProducts = data.filter(p => 
          p && typeof p === 'object' && 
          typeof p.id === 'number' && 
          p.name !== undefined
        );
        
        if (validProducts.length === 0 && data.length > 0) {
          setDebugInfo(`API returned ${data.length} items but none had valid structure`);
          console.warn('Invalid product data:', data);
        }
        
        setProducts(validProducts);
        setDebugInfo(`Loaded ${validProducts.length} valid products`);
      } catch (err) {
        let errorMsg = 'Failed to load products';
        
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
        setDebugInfo(`URL: ${err.config?.url || 'N/A'} | Status: ${err.response?.status || 'N/A'}`);
        console.error('Product fetch error:', err);
      } finally {
        setIsLoading(false);
      }
    };

    fetchProducts();
  }, []);

  if (isLoading) {
    return <Loader message="Loading products..." />;
  }

  return (
    <div>
      <div className="page-header">
        <h1 className="page-title">Product Inventory</h1>
        <Link to="/create-product" className="btn btn-primary">
          Add New Product
        </Link>
      </div>

      {error && (
        <div className="alert alert-error">
          <p>{error}</p>
          <p className="debug-info">{debugInfo}</p>
        </div>
      )}

      <div className="product-grid">
        {products.length > 0 ? (
          products.map(product => (
            <ProductCard key={product.id} product={product} />
          ))
        ) : (
          <div className="empty-state">
            <p>No products found. Create your first product!</p>
            <Link to="/create-product" className="btn btn-primary">
              Create Product
            </Link>
          </div>
        )}
      </div>
    </div>
  );
};

export default ProductListPage;