pipeline {
    agent any

    environment {
        DOCKER_USERNAME = credentials('docker-hub-username')
        DOCKER_PASSWORD = credentials('docker-hub-password')
        APP_VERSION = "${BUILD_NUMBER}"
        IMAGE_NAME = "${DOCKER_USERNAME}/blue-green-app"
        PROJECT_PATH = '/var/jenkins_home/workspace/Blue-Green-Deployment'
    }

    stages {
        stage('Checkout') {
            steps {
                script {
                    echo 'Setting up project files'
                // Copy files from Windows host to Jenkins workspace
                // We'll handle this differently
                }
            }
        }

        stage('Verify Files') {
            steps {
                script {
                    sh '''
                        echo "Current directory:"
                        pwd
                        echo "Listing files:"
                        ls -la
                    '''
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    echo "Building Docker image version ${APP_VERSION}"
                    sh """
                        docker build -t ${DOCKER_USERNAME}/blue-green-app:${APP_VERSION} .
                        docker tag ${DOCKER_USERNAME}/blue-green-app:${APP_VERSION} ${DOCKER_USERNAME}/blue-green-app:latest
                    """
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                script {
                    echo 'Pushing image to Docker Hub'
                    sh """
                        echo ${DOCKER_PASSWORD} | docker login -u ${DOCKER_USERNAME} --password-stdin
                        docker push ${DOCKER_USERNAME}/blue-green-app:${APP_VERSION}
                        docker push ${DOCKER_USERNAME}/blue-green-app:latest
                    """
                }
            }
        }

        stage('Determine Active Environment') {
            steps {
                script {
                    def nginxConfig = readFile('nginx/nginx.conf')
                    if (nginxConfig.contains('server blue-app:3000')) {
                        env.ACTIVE_ENV = 'blue'
                        env.TARGET_ENV = 'green'
                    } else {
                        env.ACTIVE_ENV = 'green'
                        env.TARGET_ENV = 'blue'
                    }
                    echo "Active environment: ${env.ACTIVE_ENV}"
                    echo "Target environment: ${env.TARGET_ENV}"
                }
            }
        }

        stage('Deploy to Inactive Environment') {
            steps {
                script {
                    echo "Deploying version ${APP_VERSION} to ${TARGET_ENV} environment"
                    sh """
                        export VERSION=${APP_VERSION}
                        export DOCKER_USERNAME=${DOCKER_USERNAME}
                        docker-compose -f docker-compose.${TARGET_ENV}.yml down
                        docker-compose -f docker-compose.${TARGET_ENV}.yml pull
                        docker-compose -f docker-compose.${TARGET_ENV}.yml up -d
                    """
                }
            }
        }

        stage('Health Check') {
            steps {
                script {
                    echo "Running health checks on ${TARGET_ENV} environment"
                    def targetPort = (env.TARGET_ENV == 'blue') ? '3001' : '3002'

                    retry(5) {
                        sleep 5
                        sh "curl -f http://host.docker.internal:${targetPort}/health"
                    }

                    echo "Health check passed for ${TARGET_ENV} environment"
                }
            }
        }

        stage('Switch Traffic') {
            steps {
                script {
                    echo "Switching traffic from ${ACTIVE_ENV} to ${TARGET_ENV}"

                    // Update nginx config
                    if (env.TARGET_ENV == 'blue') {
                        sh '''
                            cat > nginx/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream backend {
        server blue-app:3000;
    }

    server {
        listen 80;

        location / {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        location /health {
            proxy_pass http://backend/health;
        }
    }
}
EOF
                        '''
                    } else {
                        sh '''
                            cat > nginx/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream backend {
        server green-app:3000;
    }

    server {
        listen 80;

        location / {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        location /health {
            proxy_pass http://backend/health;
        }
    }
}
EOF
                        '''
                    }

                    sh 'docker exec nginx-lb nginx -s reload'
                    sleep 5
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script {
                    echo 'Verifying deployment through Nginx'
                    sh 'curl -f http://host.docker.internal:8080/'
                    echo 'Deployment verified successfully!'
                }
            }
        }

        stage('Cleanup Old Environment') {
            steps {
                script {
                    echo "Keeping ${ACTIVE_ENV} environment running as backup"
                    echo 'Old environment can be manually stopped if needed'
                }
            }
        }
    }

    post {
        success {
            echo 'Deployment completed successfully!'
            echo "New version ${APP_VERSION} is now live on ${TARGET_ENV} environment"
        }
        failure {
            echo 'Deployment failed! Rolling back...'
            script {
                // Rollback to active environment
                if (env.ACTIVE_ENV == 'blue') {
                    sh '''
                        cat > nginx/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream backend {
        server blue-app:3000;
    }

    server {
        listen 80;

        location / {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        location /health {
            proxy_pass http://backend/health;
        }
    }
}
EOF
                    '''
                } else {
                    sh '''
                        cat > nginx/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream backend {
        server green-app:3000;
    }

    server {
        listen 80;

        location / {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        location /health {
            proxy_pass http://backend/health;
        }
    }
}
EOF
                    '''
                }
                sh 'docker exec nginx-lb nginx -s reload'
            }
        }
        always {
            sh 'docker logout || true'
        }
    }
}
