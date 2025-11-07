locals {
  # Common tags applied to all resources
  common_tags = merge(
    var.common_tags,
    {
      Environment = var.environment
      Owner       = "DevOps Team"
      Project     = "EC2-ALB-Nginx"
    }
  )

  # Nginx installation and configuration user data script
  user_data_script = <<-EOF
    #!/bin/bash
    # Update system packages
    dnf update -y

    # Install Nginx web server
    dnf install -y nginx

    # Start and enable Nginx service
    systemctl start nginx
    systemctl enable nginx

    # Create health check endpoint
    echo "OK" > /usr/share/nginx/html/health

    # Create custom welcome page with instance metadata
    cat > /usr/share/nginx/html/index.html <<'HTML'
    <!DOCTYPE html>
    <html>
    <head>
      <title>EC2 ALB Nginx - High Availability Web Server</title>
      <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f4f4f4; }
        .container { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; }
        .info { background: #e3f2fd; padding: 15px; border-left: 4px solid #2196F3; margin: 15px 0; }
        .status { color: #4CAF50; font-weight: bold; }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>🚀 High-Availability Web Infrastructure</h1>
        <p class="status">✓ Server Status: Running</p>
        <div class="info">
          <p><strong>Availability Zone:</strong> <span id="az">Loading...</span></p>
          <p><strong>Instance ID:</strong> <span id="instance-id">Loading...</span></p>
          <p><strong>Web Server:</strong> Nginx</p>
          <p><strong>Deployment:</strong> Multi-AZ with Application Load Balancer</p>
        </div>
        <p><em>Infrastructure managed by Terraform | Powered by AWS</em></p>
      </div>
      <script>
        // Fetch instance metadata (this runs on the client side via ALB)
        fetch('/latest/meta-data/placement/availability-zone')
          .then(r => r.text())
          .then(data => document.getElementById('az').textContent = data)
          .catch(() => document.getElementById('az').textContent = 'ap-southeast-2a/2b');

        fetch('/latest/meta-data/instance-id')
          .then(r => r.text())
          .then(data => document.getElementById('instance-id').textContent = data)
          .catch(() => document.getElementById('instance-id').textContent = 'Multiple instances');
      </script>
    </body>
    </html>
    HTML
  EOF
}
