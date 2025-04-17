import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { List, ListItem, ListItemText, Typography } from '@material-ui/core';

function Orders() {
  const [orders, setOrders] = useState([]);

  useEffect(() => {
    // Assuming user ID 1 for simplicity
    axios.get('http://localhost:5001/api/order/user/1')
      .then(response => setOrders(response.data))
      .catch(error => console.error('Error fetching orders:', error));
  }, []);

  return (
    <div>
      <Typography variant="h4">Your Orders</Typography>
      <List>
        {orders.map(order => (
          <ListItem key={order.id}>
            <ListItemText 
              primary={`Order #${order.id}`} 
              secondary={`Status: ${order.status}, Total: $${order.totalAmount}`} 
            />
          </ListItem>
        ))}
      </List>
    </div>
  );
}

export default Orders;