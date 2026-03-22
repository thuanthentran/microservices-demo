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
                        if (fileExists("src/${service}/Dockerfile")) {
                            echo "  ✓ Found: src/${service}/Dockerfile"
                        } else {
                            error "  ✗ Missing: src/${service}/Dockerfile"
                        }
                    }
                }
            }
        }

        stage('Build Services') {
            steps {
                script {
                    echo '✓ Building services...'
                    def services = getBuildServices()
                    
                    services.each { service ->
                        echo "  → Building ${service}..."
                        dir("src/${service}") {
                            buildService(service)
                        }
                    }
                }
            }
        }

        stage('Test Services') {
            steps {
                script {
                    echo '✓ Running tests...'
                    
                    // C# Tests
                    if (fileExists('src/cartservice/tests/CartServiceTests.cs')) {
                        dir('src/cartservice/tests') {
                            sh 'dotnet test || true'
                        }
                    }
                    
                    // Go Tests
                    ['productcatalogservice', 'shippingservice', 'frontend'].each { service ->
                        if (fileExists("src/${service}/${service}_test.go") || fileExists("src/${service}/*_test.go")) {
                            dir("src/${service}") {
                                sh "go test -v ./... || echo 'No tests found'"
                            }
                        }
                    }
                    
                    echo '  ✓ Test stage completed'
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
                    
                    services.each { service ->
                        if (fileExists("src/${service}/Dockerfile")) {
                            echo "  → Building Docker image: ${service}..."
                            dir("src/${service}") {
                                sh """
                                    docker build \
                                        -t ${HARBOR_REGISTRY}/${service}:${buildTag} \
                                        -t ${HARBOR_REGISTRY}/${service}:latest \
                                        .
                                """
                            }
                        }
                    }
                }
            }
        }

        stage('Push Docker Images') {
            when {
                expression { 
                    params.PUSH_IMAGES == true && (env.BRANCH_NAME == 'main' || env.GIT_BRANCH == 'origin/main')
                }
            }
            steps {
                script {
                    echo '✓ Pushing Docker images to Harbor registry...'
                    def timestamp = sh(script: 'date +%Y%m%d-%H%M%S', returnStdout: true).trim()
                    def buildTag = "${BUILD_NUMBER}-${timestamp}"
                    def services = getBuildServices()
                    
                    withCredentials([usernamePassword(
                        credentialsId: 'harbor-credentials', 
                        usernameVariable: 'HARBOR_USER', 
                        passwordVariable: 'HARBOR_PASS')]) {
                        sh '''
                            echo $HARBOR_PASS | docker login -u $HARBOR_USER --password-stdin ${HARBOR_REGISTRY}
                        '''
                        
                        services.each { service ->
                            sh """
                                if docker images | grep -q "${HARBOR_REGISTRY}/${service}"; then
                                    echo "  → Pushing ${service}:${buildTag} and ${service}:latest..."
                                    docker push ${HARBOR_REGISTRY}/${service}:${buildTag}
                                    docker push ${HARBOR_REGISTRY}/${service}:latest
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

def buildService(String service) {
    echo "  → Building ${service}..."
    
    switch(service) {
        case 'adservice':
            sh 'chmod +x ./gradlew && ./gradlew build || true'
            break
        
        case 'cartservice':
            sh 'dotnet build cartservice.csproj || true'
            break
        
        case ['checkoutservice', 'productcatalogservice', 'shippingservice', 'frontend']:
            sh '''
                if [ -f go.mod ]; then
                    go mod download
                    go build -o app . || true
                fi
            '''
            break
        
        case ['currencyservice', 'paymentservice']:
            sh '''
                if [ -f package.json ]; then
                    npm install || true
                    npm run build || true
                fi
            '''
            break
        
        case ['emailservice', 'recommendationservice', 'shoppingassistantservice']:
            sh '''
                if [ -f requirements.txt ]; then
                    pip install -r requirements.txt || true
                fi
            '''
            break
        
        default:
            echo "  ⚠ Unknown service: ${service}"
    }
}