import React from 'react';
import { BrowserRouter as Router, Route, Routes } from 'react-router-dom';
import { CssBaseline, Container } from '@material-ui/core';
import NavBar from './components/NavBar';
import Products from './components/Products';
import Orders from './components/Orders';
import Profile from './components/Profile';

function App() {
  return (
    <Router>
      <CssBaseline />
      <NavBar />
      <Container>
        <Routes>
          <Route path="/" element={<Products />} />
          <Route path="/orders" element={<Orders />} />
          <Route path="/profile" element={<Profile />} />
        </Routes>
      </Container>
    </Router>
  );
}

export default App;