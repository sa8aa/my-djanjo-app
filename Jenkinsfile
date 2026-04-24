pipeline {
    agent any

    environment {
        DOCKER_IMAGE    = "sa8aa/my-djanjo-app"
        AWS_REGION      = "eu-west-1"
        AWS_ACCOUNT_ID  = "123456789012"
        ECR_REPO        = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/my-djanjo-app"
        KUBE_CONFIG     = "/var/jenkins_home/.kube/config"
        TF_DIR          = "terraform"
        IMAGE_TAG       = "v${BUILD_NUMBER}-${GIT_COMMIT.take(7)}"
        ECR_KEEP        = "5"
    }

    stages {
        stage('Checkout')          { steps { git branch: 'main', url: 'https://github.com/sa8aa/my-djanjo-app.git' } }
        stage('Tests')             { steps { sh 'chmod +x scripts/test.sh && bash scripts/test.sh' } }
        stage('Build Image')       { steps { sh "docker build -t ${DOCKER_IMAGE}:${IMAGE_TAG} -t ${DOCKER_IMAGE}:latest -t ${ECR_REPO}:${IMAGE_TAG} -t ${ECR_REPO}:latest ." } }
        stage('Push DockerHub')    { steps { withCredentials([usernamePassword(credentialsId:'dockerhub-credentials', usernameVariable:'U', passwordVariable:'P')]) { sh "echo \$P | docker login -u \$U --password-stdin && docker push ${DOCKER_IMAGE}:${IMAGE_TAG} && docker push ${DOCKER_IMAGE}:latest" } } }
        stage('Push ECR')          { steps { withCredentials([usernamePassword(credentialsId:'aws-credentials', usernameVariable:'AWS_ACCESS_KEY_ID', passwordVariable:'AWS_SECRET_ACCESS_KEY')]) { sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com && docker push ${ECR_REPO}:${IMAGE_TAG} && docker push ${ECR_REPO}:latest" } } }
        stage('Terraform')         { steps { withCredentials([usernamePassword(credentialsId:'aws-credentials', usernameVariable:'AWS_ACCESS_KEY_ID', passwordVariable:'AWS_SECRET_ACCESS_KEY')]) { dir("${TF_DIR}") { sh "terraform init -input=false && terraform apply -var='image_tag=${IMAGE_TAG}' -var='aws_account_id=${AWS_ACCOUNT_ID}' -auto-approve -input=false" } } } }
        stage('Deploy EKS')        { steps { sh "export KUBECONFIG=${KUBE_CONFIG} && sed -i 's|IMAGE_PLACEHOLDER|${ECR_REPO}:${IMAGE_TAG}|g' k8s/k8s-deployment.yaml && kubectl apply -f k8s/k8s-deployment.yaml && kubectl rollout status deployment/ims-project --timeout=120s" }
                                     post { failure { sh "export KUBECONFIG=${KUBE_CONFIG} && kubectl rollout undo deployment/ims-project" } } }
        stage('Verify')            { steps { sh "export KUBECONFIG=${KUBE_CONFIG} && kubectl get pods -l app=ims-project && kubectl get svc ims-project" } }
    }

    post {
        always { sh "docker rmi ${DOCKER_IMAGE}:${IMAGE_TAG} ${ECR_REPO}:${IMAGE_TAG} || true && docker image prune -f || true" }
        success { echo "SUCCESS — ${ECR_REPO}:${IMAGE_TAG}" }
        failure { echo "FAILED — check logs" }
    }
}
