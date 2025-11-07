const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;
const VERSION = process.env.VERSION || '1.0.0';
const ENV = process.env.ENV || 'unknown';

app.get('/', (req, res) => {
  res.json({
    message: 'Heyy from Blue-Green Deployment! This is RS',
    version: VERSION,
    environment: ENV,
    timestamp: new Date().toISOString()
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', environment: ENV });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT} - Environment: ${ENV} - Version: ${VERSION}`);
});