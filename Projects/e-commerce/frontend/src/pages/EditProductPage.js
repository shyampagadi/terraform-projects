import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import ProductForm from '../components/ProductForm';
import productService from '../api/productService';
import Loader from '../components/Loader';

const EditProductPage = () => {
  const { id } = useParams();
  const [product, setProduct] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    const fetchProduct = async () => {
      try {
        setIsLoading(true);
        setError('');
        const data = await productService.getById(id);
        setProduct(data);
      } catch (err) {
        let errorMsg = 'Failed to load product';
        
        if (err.response?.data?.detail) {
          errorMsg = err.response.data.detail;
        } else if (err.message) {
          errorMsg = err.message;
        }
        
        setError(errorMsg);
        console.error('Failed to load product', err);
      } finally {
        setIsLoading(false);
      }
    };

    fetchProduct();
  }, [id]);

  if (isLoading) return <Loader message={`Loading product ${id}...`} />;

  return (
    <div className="edit-product-page">
      <h1 className="page-title">Edit Product</h1>
      
      {error && (
        <div className="alert alert-error">
          <p>{error}</p>
          <Link to="/products" className="btn btn-secondary">
            Back to Products
          </Link>
        </div>
      )}
      
      {!error && product ? (
        <ProductForm product={product} />
      ) : !error ? (
        <div className="alert alert-error">
          <p>Product not found</p>
          <Link to="/products" className="btn btn-secondary">
            Back to Products
          </Link>
        </div>
      ) : null}
    </div>
  );
};

export default EditProductPage;