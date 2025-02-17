pipeline {
    agent any

    environment {
//         AZURE_CLIENT_ID = credentials('AZURE_CLIENT_ID')
//         AZURE_CLIENT_SECRET = credentials('AZURE_CLIENT_SECRET')
//         AZURE_TENANT_ID = credentials('AZURE_TENANT_ID')
//         AZURE_SUBSCRIPTION_ID = credentials('AZURE_SUBSCRIPTION_ID')
        AZURE_CREDENTIALS = credentials('azure-service-principal')
    }

    stages {
        stage('Clone Repository') {
            steps {
                 git branch: 'main', credentialsId: 'git-ssh-key', url: 'https://github.com/sid326/PostgresTerrformDeployment.git'
            }
        }

        stage('Initialize Terraform') {
            steps {
                sh 'terraform init'
            }
        }

        stage('Azure Login') {
                            steps {
                                script {
                                    withCredentials([azureServicePrincipal('azure-service-principal')]) {
                                        sh '''
                                            az login --service-principal \
                                                -u $AZURE_CREDENTIALS_CLIENT_ID \
                                                -p $AZURE_CREDENTIALS_CLIENT_SECRET \
                                                --tenant $AZURE_CREDENTIALS_TENANT_ID
                                        '''
                                    }
                                }
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
