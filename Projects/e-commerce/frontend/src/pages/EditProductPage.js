import React, { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';
import ProductForm from '../components/ProductForm';
import productService from '../api/productService';

const EditProductPage = () => {
  const { id } = useParams();
  const [product, setProduct] = useState(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const fetchProduct = async () => {
      try {
        const data = await productService.getById(id);
        setProduct(data);
      } catch (err) {
        console.error('Failed to load product', err);
      } finally {
        setIsLoading(false);
      }
    };

    fetchProduct();
  }, [id]);

  if (isLoading) return <div>Loading product...</div>;

  return (
    <div>
      <h1 className="page-title">Edit Product</h1>
      {product ? (
        <ProductForm product={product} />
      ) : (
        <div className="alert alert-error">Product not found</div>
      )}
    </div>
  );
};

export default EditProductPage;