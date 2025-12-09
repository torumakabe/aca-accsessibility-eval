// =============================================================================
// container-app.bicep - Container App for verification
// =============================================================================

@description('アプリ名')
param name string

@description('リージョン')
param location string

@description('Container Apps EnvironmentのリソースID')
param environmentId string

@description('コンテナイメージ')
param containerImage string = 'mcr.microsoft.com/k8se/quickstart:latest'

@description('ターゲットポート')
param targetPort int = 80

@description('外部Ingress有効化')
param externalIngress bool = true

// -----------------------------------------------------------------------------
// Container App
// -----------------------------------------------------------------------------
resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: name
  location: location
  properties: {
    environmentId: environmentId
    workloadProfileName: 'Consumption'
    configuration: {
      ingress: externalIngress
        ? {
            external: true
            targetPort: targetPort
            transport: 'auto'
            allowInsecure: false
          }
        : null
    }
    template: {
      containers: [
        {
          name: 'main'
          image: containerImage
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

// -----------------------------------------------------------------------------
// Outputs
// -----------------------------------------------------------------------------
@description('Container AppのリソースID')
output id string = containerApp.id

@description('Container Appの名前')
output name string = containerApp.name

@description('Container AppのFQDN')
output fqdn string = containerApp.properties.configuration.ingress.fqdn
