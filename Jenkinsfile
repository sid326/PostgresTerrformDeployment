pipeline {
    agent any

    environment {
        AZURE_CLIENT_ID = credentials('AZURE_CLIENT_ID')
        AZURE_CLIENT_SECRET = credentials('AZURE_CLIENT_SECRET')
        AZURE_TENANT_ID = credentials('AZURE_TENANT_ID')
        AZURE_SUBSCRIPTION_ID = credentials('AZURE_SUBSCRIPTION_ID')
    }

    stages {
        stage('Clone Repository') {
            steps {
                git branch: 'main', url: 'https://github.com/YOUR_USERNAME/YOUR_REPO.git'
            }
        }

        stage('Initialize Terraform') {
            steps {
                sh 'terraform init'
            }
        }

        stage('Plan Terraform Deployment') {
            steps {
                sh 'terraform plan -out=tfplan'
            }
        }

        stage('Apply Terraform Configuration') {
            steps {
                sh 'terraform apply -auto-approve tfplan'
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'terraform.tfstate', fingerprint: true
        }
        success {
            echo "Terraform Deployment Successful!"
        }
        failure {
            echo "Terraform Deployment Failed!"
        }
    }
}
