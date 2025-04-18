import React, { useState, useEffect } from 'react';
import { Paper, Typography, TextField, Button, Box } from '@mui/material';
import axios from 'axios';

function Profile() {
  const [user, setUser] = useState(null);

  useEffect(() => {
    axios.get('http://localhost:5002/api/user/1')
      .then(response => setUser(response.data))
      .catch(error => console.error('Error fetching user:', error));
  }, []);

  const handleSubmit = (event) => {
    event.preventDefault();
    console.log('Updated user:', user);
  };

  if (!user) return <Typography>Loading...</Typography>;

  return (
    <Paper sx={{ mt: 2, p: 3 }}>
      <Typography variant="h4" sx={{ mb: 3 }}>Your Profile</Typography>
      <Box component="form" onSubmit={handleSubmit}>
        <TextField 
          fullWidth 
          margin="normal" 
          label="Username" 
          value={user.username} 
          onChange={e => setUser({...user, username: e.target.value})}
        />
        <TextField 
          fullWidth 
          margin="normal" 
          label="Email" 
          value={user.email} 
          onChange={e => setUser({...user, email: e.target.value})}
        />
        <TextField 
          fullWidth 
          margin="normal" 
          label="First Name" 
          value={user.firstName} 
          onChange={e => setUser({...user, firstName: e.target.value})}
        />
        <TextField 
          fullWidth 
          margin="normal" 
          label="Last Name" 
          value={user.lastName} 
          onChange={e => setUser({...user, lastName: e.target.value})}
        />
        <Button 
          type="submit" 
          variant="contained" 
          sx={{ mt: 2 }}
        >
          Update Profile
        </Button>
      </Box>
    </Paper>
  );
}

export default Profile;