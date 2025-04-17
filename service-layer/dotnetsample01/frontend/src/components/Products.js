import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { Grid, Card, CardContent, Typography, Button } from '@material-ui/core';

function Products() {
  const [products, setProducts] = useState([]);

  useEffect(() => {
    axios.get('http://localhost:5000/api/product')
      .then(response => setProducts(response.data))
      .catch(error => console.error('Error fetching products:', error));
  }, []);

  return (
    <Grid container spacing={3}>
      {products.map(product => (
        <Grid item xs={12} sm={6} md={4} key={product.id}>
          <Card>
            <CardContent>
              <Typography variant="h5">{product.name}</Typography>
              <Typography color="textSecondary">{product.description}</Typography>
              <Typography variant="body2">Price: ${product.price}</Typography>
              <Typography variant="body2">In Stock: {product.stockQuantity}</Typography>
              <Button variant="contained" color="primary">Add to Cart</Button>
            </CardContent>
          </Card>
        </Grid>
      ))}
    </Grid>
  );
}

export default Products;