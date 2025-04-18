import React from 'react';
import { AppBar, Toolbar, Typography, Button } from '@mui/material';
import { Link } from 'react-router-dom';

function NavBar() {
  return (
    <AppBar position="static">
      <Toolbar>
        <Typography variant="h6" sx={{ flexGrow: 1 }}>
          Sample App
        </Typography>
        <Button color="inherit" component={Link} to="/">Products</Button>
        <Button color="inherit" component={Link} to="/orders">Orders</Button>
        <Button color="inherit" component={Link} to="/profile">Profile</Button>
      </Toolbar>
    </AppBar>
  );
}

export default NavBar;