module.exports = {
  apps: [
    {
      name: 'container-inspection-backend',
      cwd: __dirname,
      script: './venv/Scripts/uvicorn.exe',
      args: 'app.main:app --host 127.0.0.1 --port 8000',
      interpreter: 'none',
      autorestart: true,
      max_restarts: 10,
    },
  ],
};
