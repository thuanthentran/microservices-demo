pipeline {
    agent any

    environment {
        DOCKER_BUILDKIT = '1'
        BUILDKIT_PROGRESS = 'plain'
    }

    parameters {
        choice(
            name: 'BUILD_TARGET',
            choices: ['all', 'adservice', 'cartservice', 'checkoutservice', 'currencyservice', 
                     'emailservice', 'frontend', 'paymentservice', 'productcatalogservice', 
                     'recommendationservice', 'shippingservice', 'shoppingassistantservice'],
            description: 'Select which service(s) to build'
        )
        booleanParam(name: 'PUSH_IMAGES', defaultValue: false, description: 'Push Docker images to Harbor?')
        string(name: 'HARBOR_REGISTRY', defaultValue: 'localhost:5000', description: 'Harbor registry URL (e.g., 192.168.1.100:5000)')
    }
 
    stages {
        stage('Checkout') {
            steps {
                script {
                    echo '✓ Checking out repository...'
                    checkout scm
                    echo "✓ Repository checked out - Commit: ${env.GIT_COMMIT}"
                }
            }
        }

        stage('Validate Services') {
            steps {
                script {
                    echo '✓ Validating service structure...'
                    def services = getServiceList()
                    services.each { service ->
                        def dockerfilePath = getDockerfilePath(service)
                        if (fileExists(dockerfilePath)) {
                            echo "  ✓ Found: ${dockerfilePath}"
                        } else {
                            error "  ✗ Missing: ${dockerfilePath}"
                        }
                    }
                }
            }
        }



        stage('Build Docker Images') {
            steps {
                script {
                    echo '✓ Building Docker images...'
                    def services = getBuildServices()
                    def timestamp = sh(script: 'date +%Y%m%d-%H%M%S', returnStdout: true).trim()
                    def buildTag = "${BUILD_NUMBER}-${timestamp}"
                    def harborProject = 'sample-microservice'
                    
                    services.each { service ->
                        def dockerfilePath = getDockerfilePath(service)
                        if (fileExists(dockerfilePath)) {
                            echo "  → Building Docker image: ${service}..."
                            
                            // Determine context directory based on service
                            def contextDir
                            if (service == 'cartservice') {
                                contextDir = 'src/cartservice/src'
                            } else {
                                contextDir = "src/${service}"
                            }
                            
                            dir(contextDir) {
                                sh """
                                    docker build \
                                        -f Dockerfile \
                                        -t ${HARBOR_REGISTRY}/${harborProject}/${service}:${buildTag} \
                                        -t ${HARBOR_REGISTRY}/${harborProject}/${service}:latest \
                                        .
                                """
                            }
                        } else {
                            echo "  ⚠ Warning: Dockerfile not found at ${dockerfilePath}, skipping ${service}"
                        }
                    }
                }
            }
        }

        stage('Push Docker Images') {
            when {
                expression { 
                    params.PUSH_IMAGES == true
                }
            }
            steps {
                script {
                    echo '✓ Pushing Docker images to Harbor registry...'
                    def timestamp = sh(script: 'date +%Y%m%d-%H%M%S', returnStdout: true).trim()
                    def buildTag = "${BUILD_NUMBER}-${timestamp}"
                    def services = getBuildServices()
                    def harborProject = 'sample-microservice'
                    
                    withCredentials([usernamePassword(
                        credentialsId: 'jenkin-cred', 
                        usernameVariable: 'HARBOR_USER', 
                        passwordVariable: 'HARBOR_PASS')]) {
                        sh '''
                            echo $HARBOR_PASS | docker login -u $HARBOR_USER --password-stdin ${HARBOR_REGISTRY}
                        '''
                        
                        services.each { service ->
                            sh """
                                if docker images | grep -q "${HARBOR_REGISTRY}/${harborProject}/${service}"; then
                                    echo "  → Pushing ${service}:${buildTag} and ${service}:latest..."
                                    docker push ${HARBOR_REGISTRY}/${harborProject}/${service}:${buildTag}
                                    docker push ${HARBOR_REGISTRY}/${harborProject}/${service}:latest
                                    echo "  ✓ ${service} pushed successfully"
                                fi
                            """
                        }
                        
                        sh 'docker logout || true'
                    }
                }
            }
        }

        stage('Security Scan') {
            when {
                expression { env.BRANCH_NAME == 'main' || env.GIT_BRANCH == 'origin/main' }
            }
            steps {
                script {
                    echo '✓ Running security scans...'
                    // Add your security scanning tools here
                    // Example: trivy, snyk, or similar
                    sh 'echo "  → Security scan placeholder"'
                }
            }
        }

        stage('Deploy') {
            when {
                expression { env.BRANCH_NAME == 'main' || env.GIT_BRANCH == 'origin/main' }
            }
            steps {
                script {
                    echo '✓ Deploying services...'
                    // Add your deployment logic here
                    // Examples:
                    // - docker-compose up
                    // - kubectl apply -f k8s/
                    // - Terraform apply
                    sh '''
                        echo "  → Deployment placeholder"
                        echo "  → Configure your deployment process here"
                    '''
                }
            }
        }
    }

    post {
        always {
            echo '✓ Pipeline execution completed'
            sh 'docker logout || true'
        }
        failure {
            echo '✗ Pipeline failed!'
            // Send notifications
        }
        success {
            echo '✓ Pipeline succeeded!'
        }
    }
}

// ==================== Helper Functions ====================

def getServiceList() {
    return ['adservice', 'cartservice', 'checkoutservice', 'currencyservice',
            'emailservice', 'frontend', 'paymentservice', 'productcatalogservice',
            'recommendationservice', 'shippingservice', 'shoppingassistantservice']
}

def getBuildServices() {
    if (params.BUILD_TARGET == 'all') {
        return getServiceList()
    } else {
        return [params.BUILD_TARGET]
    }
}

def getDockerfilePath(String service) {
    // Handle special cases where Dockerfile is not in the root of service directory
    switch(service) {
        case 'cartservice':
            return "src/${service}/src/Dockerfile"
        default:
            return "src/${service}/Dockerfile"
    }
}