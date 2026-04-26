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

    }

    post {
        success { echo "Pipeline passed" }
        failure { echo "Pipeline failed — check logs above" }
    }
}

