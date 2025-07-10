import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { TextField, Button, Container, Box } from '@mui/material';
import productService from '../api/productService';

const ProductForm = ({ product }) => {
  const [formData, setFormData] = useState(product || {
    name: '',
    description: '',
    price: 0,
    category: ''
  });
  
  const navigate = useNavigate();

  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (product) {
        await productService.update(product.id, formData);
      } else {
        await productService.create(formData);
      }
      navigate('/products');
    } catch (error) {
      console.error('Operation failed:', error);
    }
  };

  return (
    <Container maxWidth="sm">
      <Box component="form" onSubmit={handleSubmit} sx={{ mt: 3 }}>
        <TextField
          label="Product Name"
          name="name"
          value={formData.name}
          onChange={handleChange}
          fullWidth
          margin="normal"
          required
        />
        <TextField
          label="Description"
          name="description"
          value={formData.description}
          onChange={handleChange}
          fullWidth
          margin="normal"
          multiline
          rows={4}
        />
        <TextField
          label="Price"
          name="price"
          type="number"
          value={formData.price}
          onChange={handleChange}
          fullWidth
          margin="normal"
          required
        />
        <TextField
          label="Category"
          name="category"
          value={formData.category}
          onChange={handleChange}
          fullWidth
          margin="normal"
        />
        <Button 
          type="submit" 
          variant="contained" 
          color="primary"
          sx={{ mt: 2 }}
        >
          {product ? 'Update Product' : 'Create Product'}
        </Button>
      </Box>
    </Container>
  );
};

export default ProductForm;