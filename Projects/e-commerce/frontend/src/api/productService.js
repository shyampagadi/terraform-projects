import axios from 'axios';
import config from '../config/config';

const API = axios.create({
  baseURL: config.apiBaseUrl,
  timeout: 10000,
  headers: { 'Content-Type': 'application/json' }
});

export default {
  async getAll() {
    const response = await API.get('/products/');
    return response.data;
  },

  async getById(id) {
    const response = await API.get(`/products/${id}`);
    return response.data;
  },

  async create(product) {
    const response = await API.post('/products/', product);
    return response.data;
  },

  async update(id, product) {
    const response = await API.put(`/products/${id}`, product);
    return response.data;
  },

  async delete(id) {
    const response = await API.delete(`/products/${id}`);
    return response.data;
  }
};