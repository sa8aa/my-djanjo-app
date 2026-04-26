pipeline {
    agent any

    environment {
        DOCKER_IMAGE   = "sa8aa/my-djanjo-app"
        AWS_REGION     = "us-east-1"
        AWS_ACCOUNT_ID = "284208999443"
        ECR_REPO       = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/my-djanjo-app"
        KUBE_CONFIG    = "/var/jenkins_home/.kube/config"
        TF_DIR         = "terraform"
        ECR_KEEP       = "5"
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'feature/jenkins-pipeline',
                    url: 'https://github.com/sa8aa/my-djanjo-app.git'
            }
            post {
                success {
                    script {
                        env.IMAGE_TAG = "v${BUILD_NUMBER}-${GIT_COMMIT.take(7)}"
                        echo "Checkout successful"
                        echo "Commit  : ${GIT_COMMIT}"
                        echo "Image tag: ${env.IMAGE_TAG}"
                    }
                }
            }
        }
        stage('Tests') {
            steps {
                sh 'chmod +x scripts/test.sh && bash scripts/test.sh'
            }
            post {
                success { echo "Tests passed" }
                failure { echo "Tests failed — pipeline aborted" }
            }
        }
          stage('Build Image') {
            steps {
                sh """
                    docker build \
                        -t ${DOCKER_IMAGE}:${IMAGE_TAG} \
                        -t ${DOCKER_IMAGE}:latest \
                        .
                """
            }
            post {
                success { echo "Image built : ${DOCKER_IMAGE}:${IMAGE_TAG}" }
                failure { echo "Docker build failed" }
            }
        }


    }

    post {
        success { echo "Pipeline passed" }
        failure { echo "Pipeline failed — check logs above" }
    }
}

