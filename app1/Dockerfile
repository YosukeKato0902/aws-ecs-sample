FROM public.ecr.aws/nginx/nginx:alpine

# Create directory for path-based routing
RUN mkdir -p /usr/share/nginx/html/app1

# Copy custom index.html to the sub-directory
COPY index.html /usr/share/nginx/html/app1/index.html

# Copy custom index.html to standard root as well (for local testing if needed)
COPY index.html /usr/share/nginx/html/index.html
