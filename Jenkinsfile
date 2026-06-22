@Library('shared-lib') _

pipeline {
    agent {
        label 'agent-huawei'
    }

    options {
        disableConcurrentBuilds()
    }

    parameters {
        string(
            name: 'PROJECT',
            defaultValue: 'pronunciation',
            description: 'Project / Environment (prefijo de recursos: vpc-<PROJECT>, ecs-<PROJECT>-app, obs-<PROJECT>-data, etc.)'
        )
        choice(
            name: 'ACTION',
            choices: ['deploy', 'destroy'],
            description: 'Accion sobre el ambiente'
        )
        booleanParam(
            name: 'RUN_TERRAFORM',
            defaultValue: false,
            description: 'Construir/destruir la infraestructura (VPC, ECS GPU con EIP, OBS+CSV, agency)'
        )
        booleanParam(
            name: 'DEPLOY_PRONUNCIATION',
            defaultValue: true,
            description: 'Desplegar el AI Pronunciation Trainer (contenedor GPU + nginx HTTPS) en el ECS.'
        )
    }

    environment {
        TF_DIR     = 'terraform'
        ANS_DIR    = 'ansible'
        OBS_REGION = 'la-south-2'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        // -- Terraform (deploy o destroy) --
        //  terraformDeploy deja en el WORKSPACE los .txt de cada output:
        //  app_public_ip.txt, ecs_private_key.txt, obs_data_bucket.txt, obs_csv_key.txt
        stage('Terraform') {
            when {
                expression { params.RUN_TERRAFORM }
            }
            steps {
                withCredentials([
                    string(credentialsId: 'hwc-access-key', variable: 'HW_ACCESS_KEY'),
                    string(credentialsId: 'hwc-secret-key', variable: 'HW_SECRET_KEY'),
                    string(credentialsId: 'hwc-access-key', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'hwc-secret-key', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    script {
                        terraformDeploy(
                            dir: env.TF_DIR,
                            varsFile: 'terraform.tfvars',
                            project: env.PROJECT,
                            action: params.ACTION,
                            outputs: [
                                'app_public_ip', 'ecs_private_key',
                                'obs_data_bucket', 'obs_csv_key'
                            ]
                        )
                    }
                }
            }
        }

        // -- Ansible: desplegar el Pronunciation Trainer --
        //  Lee los outputs DIRECTAMENTE de los .txt del workspace dentro del mismo
        //  shell. NO usa variables env.* entre etapas (eso se perdia y llegaba
        //  app_public_ip vacio -> "hostname contains invalid characters").
        stage('Deploy Pronunciation with Ansible') {
            when {
                allOf {
                    expression { params.ACTION == 'deploy' }
                    expression { params.DEPLOY_PRONUNCIATION }
                }
            }
            steps {
                dir(env.ANS_DIR) {
                    withCredentials([
                        usernamePassword(credentialsId: 'swr-jenkins', usernameVariable: 'SWR_USER', passwordVariable: 'SWR_PASS')
                    ]) {
                        sh '''
                            set -e

                            # Outputs de Terraform leidos DIRECTO de los .txt del workspace.
                            # $(cat ...) elimina el salto de linea final por si solo.
                            KEY="$WORKSPACE/ecs_private_key.txt"
                            APP_PUBLIC_IP="$(cat "$WORKSPACE/app_public_ip.txt")"
                            OBS_BUCKET="$(cat "$WORKSPACE/obs_data_bucket.txt")"
                            OBS_CSV_KEY="$(cat "$WORKSPACE/obs_csv_key.txt")"

                            # Fallar claro si la IP esta vacia (en vez del confuso "invalid characters")
                            if [ -z "$APP_PUBLIC_IP" ]; then
                                echo "ERROR: app_public_ip vacio. Corre con RUN_TERRAFORM=true y revisa el apply." >&2
                                exit 1
                            fi
                            if [ -z "$OBS_CSV_KEY" ]; then
                                OBS_CSV_KEY="data_en.csv"
                            fi

                            chmod 600 "$KEY"
                            export ANSIBLE_HOST_KEY_CHECKING=False

                            echo "Desplegando en $APP_PUBLIC_IP (bucket: $OBS_BUCKET, csv: $OBS_CSV_KEY)"

                            ansible-playbook -i inventory/hosts.yml playbooks/deploy-pronunciation.yml \\
                                --private-key "$KEY" \\
                                --extra-vars "app_env=$PROJECT \\
                                              app_public_ip=$APP_PUBLIC_IP \\
                                              obs_region=$OBS_REGION \\
                                              obs_bucket=$OBS_BUCKET \\
                                              obs_csv_key=$OBS_CSV_KEY"

                            echo "============================================================"
                            echo " Pronunciation Trainer desplegado"
                            echo " App (HTTPS): https://$APP_PUBLIC_IP"
                            echo " CSV en OBS:  $OBS_BUCKET/$OBS_CSV_KEY"
                            echo " (Edita el CSV en OBS y reinicia el ECS para refrescarlo.)"
                            echo "============================================================"
                        '''
                    }
                }
            }
        }
    }

    post {
        success {
            script {
                if (params.ACTION == 'deploy') {
                    def ip = ''
                    if (fileExists("${WORKSPACE}/app_public_ip.txt")) {
                        ip = readFile("${WORKSPACE}/app_public_ip.txt").trim()
                    }
                    currentBuild.description = ip ? "Deploy OK - Trainer (HTTPS): https://${ip}" : "Deploy OK"
                } else {
                    currentBuild.description = "Destruccion completada"
                }
            }
        }
        failure {
            script {
                currentBuild.description = "Fallo en: ${env.STAGE_NAME ?: 'N/A'} - Logs: ${env.BUILD_URL}console"
            }
        }
    }
}
