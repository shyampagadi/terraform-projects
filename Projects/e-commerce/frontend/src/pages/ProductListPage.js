import React, { useState, useEffect } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import ProductCard from '../components/ProductCard';
import Loader from '../components/Loader';
import productService from '../api/productService';

const ProductListPage = () => {
  const location = useLocation();
  const navigate = useNavigate();
  const queryParams = new URLSearchParams(location.search);
  
  const [products, setProducts] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [debugInfo, setDebugInfo] = useState('');
  
  // Filter and sort state - initialize from URL params
  const [selectedCategory, setSelectedCategory] = useState(queryParams.get('category') || '');
  const [sortBy, setSortBy] = useState('newest');
  const [searchTerm, setSearchTerm] = useState(queryParams.get('search') || '');
  
  // Categories list - dynamically populated from products
  const [categories, setCategories] = useState([]);
  
  // Update URL when filters change
  useEffect(() => {
    const params = new URLSearchParams();
    
    if (selectedCategory) {
      params.set('category', selectedCategory);
    }
    
    if (searchTerm) {
      params.set('search', searchTerm);
    }
    
    const newSearch = params.toString();
    const newUrl = newSearch ? `${location.pathname}?${newSearch}` : location.pathname;
    
    // Only update if the URL would change (prevents infinite loop)
    if (newUrl !== `${location.pathname}${location.search}`) {
      navigate(newUrl, { replace: true });
    }
  }, [selectedCategory, searchTerm, navigate, location.pathname, location.search]);
  
  // Listen for URL changes from outside (e.g. header search)
  useEffect(() => {
    const params = new URLSearchParams(location.search);
    const categoryParam = params.get('category');
    const searchParam = params.get('search');
    
    if (categoryParam !== selectedCategory) {
      setSelectedCategory(categoryParam || '');
    }
    
    if (searchParam !== searchTerm) {
      setSearchTerm(searchParam || '');
    }
  }, [location.search]);

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
        
        // Extract unique categories
        const uniqueCategories = [...new Set(validProducts.map(p => p.category).filter(Boolean))];
        setCategories(uniqueCategories);
        
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

  // Filter and sort products
  const filteredProducts = products
    .filter(product => {
      // Filter by category
      const categoryMatch = !selectedCategory || product.category === selectedCategory;
      
      // Filter by search term
      const searchMatch = !searchTerm || 
        product.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
        (product.description && product.description.toLowerCase().includes(searchTerm.toLowerCase()));
        
      return categoryMatch && searchMatch;
    })
    .sort((a, b) => {
      // Sort products
      switch (sortBy) {
        case 'price-low':
          return a.price - b.price;
        case 'price-high':
          return b.price - a.price;
        case 'name-asc':
          return a.name.localeCompare(b.name);
        case 'name-desc':
          return b.name.localeCompare(a.name);
        case 'newest':
        default:
          // Assuming newer products have higher IDs
          return b.id - a.id;
      }
    });
    
  const handleSearchSubmit = (e) => {
    e.preventDefault();
    // Search is already handled via state
  };

  if (isLoading) {
    return <Loader message="Loading products..." />;
  }

  return (
    <div className="product-list-page">
      <div className="page-header">
        <h1 className="page-title">Products</h1>
        <Link to="/create-product" className="btn btn-primary">
          <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <line x1="12" y1="5" x2="12" y2="19"></line>
            <line x1="5" y1="12" x2="19" y2="12"></line>
          </svg>
          Add New Product
        </Link>
      </div>

      {error && (
        <div className="alert alert-error">
          <p>{error}</p>
          <p className="debug-info">{debugInfo}</p>
        </div>
      )}
      
      <div className="filters-section">
        <form onSubmit={handleSearchSubmit} className="search-form">
          <div className="form-group search-group">
            <input
              type="text"
              className="form-input search-input"
              placeholder="Search products..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
            <button type="submit" className="search-button">
              <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <circle cx="11" cy="11" r="8"></circle>
                <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
              </svg>
            </button>
          </div>
        </form>
        
        <div className="filters-row">
          <div className="filter-group">
            <label htmlFor="category-filter" className="filter-label">Category:</label>
            <select
              id="category-filter"
              className="form-select"
              value={selectedCategory}
              onChange={(e) => setSelectedCategory(e.target.value)}
            >
              <option value="">All Categories</option>
              {categories.map(category => (
                <option key={category} value={category}>{category}</option>
              ))}
            </select>
          </div>
          
          <div className="filter-group">
            <label htmlFor="sort-filter" className="filter-label">Sort by:</label>
            <select
              id="sort-filter"
              className="form-select"
              value={sortBy}
              onChange={(e) => setSortBy(e.target.value)}
            >
              <option value="newest">Newest</option>
              <option value="price-low">Price: Low to High</option>
              <option value="price-high">Price: High to Low</option>
              <option value="name-asc">Name: A to Z</option>
              <option value="name-desc">Name: Z to A</option>
            </select>
          </div>
        </div>
      </div>
      
      <div className="results-summary">
        <span className="results-count">
          {filteredProducts.length} {filteredProducts.length === 1 ? 'product' : 'products'} found
        </span>
        
        {selectedCategory && (
          <div className="active-filter">
            <span>Category: {selectedCategory}</span>
            <button 
              onClick={() => setSelectedCategory('')} 
              className="clear-filter"
              aria-label="Clear category filter"
            >
              ×
            </button>
          </div>
        )}
        
        {searchTerm && (
          <div className="active-filter">
            <span>Search: "{searchTerm}"</span>
            <button 
              onClick={() => setSearchTerm('')} 
              className="clear-filter"
              aria-label="Clear search filter"
            >
              ×
            </button>
          </div>
        )}
      </div>

      <div className="product-grid">
        {filteredProducts.length > 0 ? (
          filteredProducts.map(product => (
            <ProductCard key={product.id} product={product} />
          ))
        ) : (
          <div className="empty-state">
            <svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1" strokeLinecap="round" strokeLinejoin="round">
              <circle cx="12" cy="12" r="10"></circle>
              <line x1="8" y1="12" x2="16" y2="12"></line>
            </svg>
            <h3>No products found</h3>
            {(selectedCategory || searchTerm) ? (
              <>
                <p>Try changing your filters or search terms</p>
                <button 
                  className="btn btn-secondary"
                  onClick={() => {
                    setSelectedCategory('');
                    setSearchTerm('');
                  }}
                >
                  Clear All Filters
                </button>
              </>
            ) : (
              <>
                <p>Create your first product to get started!</p>
                <Link to="/create-product" className="btn btn-primary">
                  Create Product
                </Link>
              </>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

export default ProductListPage;