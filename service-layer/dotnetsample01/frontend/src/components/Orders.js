import React, { useSteState, useEffect } from 'react';
import { List, ListItem, ListItemText, Typography, Paper } from '@mui/material';
import axios from 'axios';

function Orders() {
  const [orders, setOrders] = useState([]);

  useEffect(() => {
    axios.get('http://localhost:5001/api/order/user/1')
      .then(response => setOrders(response.data))
      .catch(error => console.error('Error fetching orders:', error));
  }, []);

  return (
    <Paper sx={{ mt: 2, p: 2 }}>
      <Typography variant="h4" sx={{ mb: 2 }}>Your Orders</Typography>
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
    </Paper>
  );
}

export default Orders;