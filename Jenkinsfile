pipeline {
  agent any

  environment {
    AWS_REGION   = 'us-east-1'
    ECR_REPO     = credentials('ecr-repo-url')   // set in Jenkins credentials
    IMAGE_TAG    = "${env.BUILD_NUMBER}"
    AWS_CREDS    = credentials('aws-credentials')
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Build Docker image') {
      steps {
        sh "docker build -t ${ECR_REPO}:${IMAGE_TAG} ."
      }
    }

    stage('Run tests') {
      steps {
        sh """
          docker run --rm \
            -e DJANGO_SETTINGS_MODULE=myproject.settings \
            ${ECR_REPO}:${IMAGE_TAG} \
            python manage.py test
        """
      }
    }

    stage('Push to ECR') {
      steps {
        withAWS(credentials: 'aws-credentials', region: AWS_REGION) {
          sh """
            aws ecr get-login-password --region ${AWS_REGION} \
              | docker login --username AWS --password-stdin ${ECR_REPO}
            docker push ${ECR_REPO}:${IMAGE_TAG}
          """
        }
      }
    }

    stage('Deploy') {
      steps {
        withAWS(credentials: 'aws-credentials', region: AWS_REGION) {
          sh """
            # Example: update ECS service
            aws ecs update-service \
              --cluster my-cluster \
              --service django-service \
              --force-new-deployment
          """
        }
      }
    }
  }

  post {
    failure {
      echo 'Pipeline failed — notify team'
    }
    success {
      echo "Deployed image tag: ${IMAGE_TAG}"
    }
  }
}
