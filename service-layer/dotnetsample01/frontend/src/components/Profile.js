import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { Typography, TextField, Button } from '@material-ui/core';

function Profile() {
  const [user, setUser] = useState(null);

  useEffect(() => {
    // Assuming user ID 1 for simplicity
    axios.get('http://localhost:5002/api/user/1')
      .then(response => setUser(response.data))
      .catch(error => console.error('Error fetching user:', error));
  }, []);

  const handleSubmit = (event) => {
    event.preventDefault();
    // Here you would typically send the updated user data to the server
    console.log('Updated user:', user);
  };

  if (!user) return <Typography>Loading...</Typography>;

  return (
    <div>
      <Typography variant="h4">Your Profile</Typography>
      <form onSubmit={handleSubmit}>
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
        <Button type="submit" variant="contained" color="primary">
          Update Profile
        </Button>
      </form>
    </div>
  );
}

export default Profile;