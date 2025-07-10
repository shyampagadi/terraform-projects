import React from 'react';

const Loader = ({ message = 'Loading...', size = 'medium' }) => {
  // Define spinner size based on prop
  const spinnerSize = size === 'small' ? 'loader-sm' : 
                      size === 'large' ? 'loader-lg' : '';
  
  return (
    <div className={`loader-container ${size === 'fullscreen' ? 'loader-fullscreen' : ''}`}>
      <div className={`loader ${spinnerSize}`}></div>
      {message && <p className="loader-text">{message}</p>}
    </div>
  );
};

export default Loader;