# Omniverse applications, profiles and versions

These configurations provide various options for deploying Omniverse applications in different environments, including AWS with different load balancer configurations, generic setups, and MetalLB-based deployments. Each profile and version file is meant to be customized based on specific requirements and infrastructure setups.

## Application Version

The Application Version is what determines the version of the application profile. It contains which Helm chart, container image, and container version will be used when an application is deployed.

## Application Profile

The application profile is the profile that is used to deploy the application. It contains what is effectively the values file for the helm chart that is defined in the Application Version.

## AWS

The files contained in this directory are the application profiles and versions for Omniverse on AWS.

> **Note:** The profiles will need adjusting based on the specifics of an AWS account.

### application-profile-nlb-auth.yaml

This application profile will create a new NLB for each streaming session for routing the streaming traffic. It further contains an example of how to achieve authentication using envoy proxy.

Key features:
```yaml
envoy:
  config:
    static_resources:
      listeners:
      - name: webrtc_signaling_listener
        address:
          socket_address:
            address: 0.0.0.0
            port_value: 49200
        filter_chains:
        - filters:
          - name: envoy.filters.network.http_connection_manager
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
              stat_prefix: signaling_http
              codec_type: AUTO
              upgrade_configs:
              - upgrade_type: websocket
              route_config:
                name: local_route
                virtual_hosts:
                - name: local_service
                  domains: ["*"]
                  routes:
                  - match:
                      prefix: "/"
                    route:
                      cluster: service_cluster
              http_filters:
              - name: envoy.filters.http.lua
                typed_config:
                  "@type": type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua
                  inline_code: |
                    function envoy_on_request(request_handle)
                      local headers = request_handle:headers()
                      local sec_websocket_protocol = headers:get("Sec-WebSocket-Protocol")
  
                      request_handle:logInfo("Lua filter: Checking Sec-WebSocket-Protocol header")
                      
                      if sec_websocket_protocol == nil then
                        request_handle:logInfo("Lua filter: Sec-WebSocket-Protocol header is missing")
                        request_handle:respond({[":status"] = "403"}, "Access denied")
                      else
                        local parts = {}
                        for part in sec_websocket_protocol:gmatch("[^,]+") do
                          table.insert(parts, part:match("^%s*(.-)%s*$"))
                        end
                        
                        local found = false
                        for _, part in ipairs(parts) do
                          if part:match("^Bearer%s") then
                            found = true
                            break
                          end
                        end
                        
                        if not found then
                          request_handle:logInfo("Lua filter: Bearer token not found in Sec-WebSocket-Protocol header")
                          request_handle:respond({[":status"] = "403"}, "Access denied")
                        else
                          request_handle:logInfo("Lua filter: Bearer token found in Sec-WebSocket-Protocol header")
                        end
                      end
                    end
              - name: envoy.filters.http.jwt_authn
                typed_config:
                  "@type": type.googleapis.com/envoy.extensions.filters.http.jwt_authn.v3.JwtAuthentication
                  providers:
                    keycloak:
                      issuer: "<replace with keycloak issuer>"
                      audiences:
                      - "<replace with audience>"
                      remote_jwks:
                        http_uri:
                          uri: "<replace with keycloak jwks_uri>"
                          cluster: keycloak_cluster
                          timeout: 5s
                        cache_duration:
                          seconds: 300
                  rules:
                  - match:
                      prefix: "/"
                    requires:
                      provider_name: "keycloak"
              - name: envoy.filters.http.router
```

Explanation:
- This configuration sets up an Envoy proxy to handle WebRTC signaling on port 49200.
- It includes a Lua script that checks for the presence of a Bearer token in the Sec-WebSocket-Protocol header.
- JWT authentication is configured to validate tokens against a Keycloak server.
- The configuration allows WebSocket upgrades, which is necessary for WebRTC signaling.
- If authentication fails, the request is denied with a 403 status code.

### application-profile-nlb-tls.yaml

This application profile will create a new NLB for each streaming session for routing the streaming traffic. It further contains an example of how to enable TLS on the NLB.

Key features:
```yaml
service:
  signalingPort: 443
  mediaPort: 80
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "<replace me with SSL cert ARN>"
    service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
    service.beta.kubernetes.io/aws-load-balancer-ssl-negotiation-policy: "ELBSecurityPolicy-TLS13-1-2-2021-06"
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
```

Explanation:
- This configuration sets up TLS termination at the NLB level.
- It uses HTTPS (port 443) for signaling and HTTP (port 80) for media.
- An SSL certificate ARN needs to be provided for the TLS configuration.
- It uses a modern TLS policy (TLS 1.3 and 1.2) for secure communications.
- The backend protocol is set to TCP, allowing the NLB to pass through the encrypted traffic to the backend services.

### application-profile-nlb.yaml

This application profile will create a new NLB for each streaming session for routing the streaming traffic. It is similar to the above profiles but does not have authentication or TLS configured. It is recommended to use this profile for testing purposes only.

Key features:
```yaml
service:
  signalingPort: 31000
  mediaPort: 31001
  healthPort: 31002
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "external"
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
    service.beta.kubernetes.io/load-balancer-source-ranges: "<replace with allowed ranged>"
    service.beta.kubernetes.io/aws-load-balancer-attributes: "load_balancing.cross_zone.enabled=true"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol: "HTTP"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-port: "8080"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-path: "/health"
  type: LoadBalancer
```

Explanation:
- This configuration sets up a basic NLB without authentication or TLS.
- It uses IP-based target groups and is internet-facing.
- The `load-balancer-source-ranges` should be set to restrict access to specific IP ranges.
- Cross-zone load balancing is enabled for better distribution of traffic.
- Health checks are configured to use HTTP protocol on port 8080 with the path "/health".
- The service type is set to LoadBalancer, which will provision an AWS NLB.

### application-profile-tgb-auth.yaml

This application profile uses pre-configured AWS NLBs through targetgroupbindings for routing the streaming traffic. It further contains an example of how to achieve authentication using envoy proxy.

Key features:
```yaml
aws:
  targetgroups:
    signaling: "<not set>"
    media: "<not set>"
  listeners:
    signaling: "<not set>"
    media: "<not set>"
envoy:
  config:
    static_resources:
      listeners:
      - name: webrtc_signaling_listener
        address:
          socket_address:
            address: 0.0.0.0
            port_value: 49200
        filter_chains:
        - filters:
          - name: envoy.filters.network.http_connection_manager
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
              stat_prefix: signaling_http
              codec_type: AUTO
              upgrade_configs:
              - upgrade_type: websocket
              route_config:
                name: local_route
                virtual_hosts:
                - name: local_service
                  domains: ["*"]
                  routes:
                  - match:
                      prefix: "/"
                    route:
                      cluster: service_cluster
              http_filters:
              - name: envoy.filters.http.lua
                typed_config:
                  "@type": type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua
                  inline_code: |
                    function envoy_on_request(request_handle)
                      local headers = request_handle:headers()
                      local sec_websocket_protocol = headers:get("Sec-WebSocket-Protocol")
  
                      request_handle:logInfo("Lua filter: Checking Sec-WebSocket-Protocol header")
                      
                      if sec_websocket_protocol == nil then
                        request_handle:logInfo("Lua filter: Sec-WebSocket-Protocol header is missing")
                        request_handle:respond({[":status"] = "403"}, "Access denied")
                      else
                        local parts = {}
                        for part in sec_websocket_protocol:gmatch("[^,]+") do
                          table.insert(parts, part:match("^%s*(.-)%s*$"))
                        end
                        
                        local found = false
                        for _, part in ipairs(parts) do
                          if part:match("^Bearer%s") then
                            found = true
                            break
                          end
                        end
                        
                        if not found then
                          request_handle:logInfo("Lua filter: Bearer token not found in Sec-WebSocket-Protocol header")
                          request_handle:respond({[":status"] = "403"}, "Access denied")
                        else
                          request_handle:logInfo("Lua filter: Bearer token found in Sec-WebSocket-Protocol header")
                        end
                      end
                    end
              - name: envoy.filters.http.jwt_authn
                typed_config:
                  "@type": type.googleapis.com/envoy.extensions.filters.http.jwt_authn.v3.JwtAuthentication
                  providers:
                    keycloak:
                      issuer: "<replace with keycloak issuer>"
                      audiences:
                      - "<replace with audience>"
                      remote_jwks:
                        http_uri:
                          uri: "<replace with keycloak jwks_uri>"
                          cluster: keycloak_cluster
                          timeout: 5s
                        cache_duration:
                          seconds: 300
                  rules:
                  - match:
                      prefix: "/"
                    requires:
                      provider_name: "keycloak"
              - name: envoy.filters.http.router
```

Explanation:
- This configuration uses TargetGroupBinding resources to connect to pre-configured NLBs.
- The Envoy proxy is set up similarly to the `application-profile-nlb-auth.yaml`, providing authentication for the WebRTC signaling traffic.
- It includes a Lua script to check for the presence of a Bearer token in the Sec-WebSocket-Protocol header.
- JWT authentication is configured to validate tokens against a Keycloak server.
- The configuration allows WebSocket upgrades, which is necessary for WebRTC signaling.
- If authentication fails, the request is denied with a 403 status code.

### application-profile-tgb.yaml

This application profile uses pre-configured AWS NLBs through targetgroupbindings for routing the streaming traffic.

Key features:
```yaml
aws:
  targetgroups:
    signaling: "<will be set dynamically>"
    media: "<will be set dynamically>"
  listeners:
    signaling: "<will be set dynamically>"
    media: "<will be set dynamically>"
```

Explanation:
- This configuration uses TargetGroupBinding resources to connect to pre-configured NLBs.
- The ARNs for the target groups and listeners will be set dynamically during deployment.

### application-profile-tgb-auth-wait-ready-envoy.yaml

This application profile uses pre-configured AWS NLBs through targetgroupbindings for routing the streaming traffic. It includes authentication using envoy proxy and a startup probe to ensure the application is ready before accepting traffic.

Key features:
```yaml
envoy:
  config: |
    node:
      id: node0
      cluster: envoy-cluster
    static_resources:
      listeners:
      - name: webrtc_signaling_listener
        address:
          socket_address:
            address: 0.0.0.0
            port_value: 49200
        filter_chains:
        - filters:
          - name: envoy.filters.network.http_connection_manager
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
              stat_prefix: signaling_http
              codec_type: AUTO
              upgrade_configs:
              - upgrade_type: websocket
              route_config:
                name: local_route
                virtual_hosts:
                - name: local_service
                  domains: ["*"]
                  routes:
                  - match:
                      prefix: "/"
                    route:
                      cluster: service_cluster
              http_filters:
              - name: envoy.filters.http.lua
                typed_config:
                  "@type": type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua
                  inline_code: |
                    function envoy_on_request(request_handle)
                      local headers = request_handle:headers()
                      local sec_websocket_protocol = headers:get("Sec-WebSocket-Protocol")
  
                      request_handle:logInfo("Lua filter: Checking Sec-WebSocket-Protocol header")
                      
                      if sec_websocket_protocol == nil then
                        request_handle:logInfo("Lua filter: Sec-WebSocket-Protocol header is missing")
                        request_handle:respond({[":status"] = "403"}, "Access denied")
                      else
                        local parts = {}
                        for part in sec_websocket_protocol:gmatch("[^,]+") do
                          table.insert(parts, part:match("^%s*(.-)%s*$"))
                        end
                        
                        local found = false
                        for _, part in ipairs(parts) do
                          if part:match("^Bearer%s") then
                            found = true
                            break
                          end
                        end
                        
                        if not found then
                          request_handle:logInfo("Lua filter: Bearer token not found in Sec-WebSocket-Protocol header")
                          request_handle:respond({[":status"] = "403"}, "Access denied")
                        else
                          request_handle:logInfo("Lua filter: Bearer token found in Sec-WebSocket-Protocol header")
                        end
                      end
                    end
              - name: envoy.filters.http.jwt_authn
                typed_config:
                  "@type": type.googleapis.com/envoy.extensions.filters.http.jwt_authn.v3.JwtAuthentication
                  providers:
                    keycloak:
                      issuer: "<replace with keycloak issuer>"
                      audiences:
                      - "<replace with audience>"
                      remote_jwks:
                        http_uri:
                          uri: "<replace with keycloak jwks_uri>"
                          cluster: keycloak_cluster
                          timeout: 5s
                        cache_duration:
                          seconds: 300
                  rules:
                  - match:
                      prefix: "/"
                    requires:
                      provider_name: "keycloak"
              - name: envoy.filters.http.router
      - name: health_listener
        address:
          socket_address:
            address: 0.0.0.0
            port_value: 8080
        filter_chains:
        - filters:
          - name: envoy.filters.network.http_connection_manager
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
              stat_prefix: health_check
              codec_type: AUTO
              route_config:
                name: local_route
                virtual_hosts:
                - name: local_service
                  domains: ["*"]
                  routes:
                  - match:
                      prefix: "/health"
                    direct_response:
                      status: 200
                      body:
                        inline_string: "OK"
              http_filters:
              - name: envoy.filters.http.router
      - name: ready_listener
        address:
          socket_address:
            address: 0.0.0.0
            port_value: 8081
        filter_chains:
        - filters:
          - name: envoy.filters.network.http_connection_manager
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
              stat_prefix: ready_check
              codec_type: AUTO
              route_config:
                name: local_route
                virtual_hosts:
                - name: local_service
                  domains: ["*"]
                  routes:
                  - match:
                      prefix: "/ready"
                    direct_response:
                      status: 200
                      body:
                        inline_string: "OK"
              http_filters:
              - name: envoy.filters.http.lua
                typed_config:
                  "@type": type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua
                  inline_code: |
                    local start_time = os.time()
                    function envoy_on_request(request_handle)
                      if os.time() - start_time < 60 then
                        request_handle:respond({[":status"] = "503"}, "Not ready yet")
                      end
                    end
              - name: envoy.filters.http.router
      clusters:
      - name: service_cluster
        connect_timeout: 0.25s
        type: STATIC
        lb_policy: ROUND_ROBIN
        load_assignment:
          cluster_name: service_cluster
          endpoints:
          - lb_endpoints:
            - endpoint:
                address:
                  socket_address:
                    address: 127.0.0.1
                    port_value: 49100  # Forwarding to the stream
startupProbe:
  failureThreshold: 30
  httpGet:
    path: /ready
    port: 8081
  initialDelaySeconds: 20
  periodSeconds: 10
```

Explanation:
- This configuration uses TargetGroupBinding resources to connect to pre-configured NLBs.
- The Envoy proxy is set up with three listeners:
  1. WebRTC signaling listener on port 49200 with authentication
  2. Health check listener on port 8080
  3. Readiness check listener on port 8081
- The WebRTC signaling listener includes authentication using a Lua script and JWT validation.
- The health check listener responds with a 200 OK status to requests on the "/health" path.
- The readiness check listener uses a Lua script to implement a delay before considering the service ready. It responds with a 503 status for the first 60 seconds after startup.
- A startup probe is configured to check the "/ready" endpoint on port 8081, allowing for a grace period before the service is considered ready to accept traffic.

### application-profile-tgb-auth-wait-ready-service.yaml

This application profile is similar to the tgb-auth-wait-ready-envoy profile but uses a different readiness check mechanism.

### application-profile-tgb-auth-wait-pending.yaml

This application profile is designed for use with pending versions of the application, incorporating a startup probe that checks if the application is ready using an nvcf-probe.

Key features:
```yaml
podAnnotations:
  nvidia.omniverse.ovas.pod.maxPendingTime: "30"
```

Explanation:
- This configuration sets a maximum pending time of 30 seconds for the pod.
- It uses an nvcf-probe for readiness checking, which is specific to NVIDIA Omniverse applications.

### application-version.yaml

The application version contains the container image and container version for the application.

### application.yaml

The application file contains a high-level description of the application and what is used to link the profiles and versions together.

## Generic

### application-profile-auth.yaml

This application profile provides a generic configuration with authentication using envoy proxy.

Key features:
```yaml
envoy:
  config:
    static_resources:
      listeners:
      - name: webrtc_signaling_listener
        address:
          socket_address:
            address: 0.0.0.0
            port_value: 49200
        filter_chains:
        - filters:
          - name: envoy.filters.network.http_connection_manager
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
              stat_prefix: signaling_http
              codec_type: AUTO
              upgrade_configs:
              - upgrade_type: websocket
              route_config:
                name: local_route
                virtual_hosts:
                - name: local_service
                  domains: ["*"]
                  routes:
                  - match:
                      prefix: "/"
                    route:
                      cluster: service_cluster
              http_filters:
              - name: envoy.filters.http.lua
                typed_config:
                  "@type": type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua
                  inline_code: |
                    function envoy_on_request(request_handle)
                      local headers = request_handle:headers()
                      local sec_websocket_protocol = headers:get("Sec-WebSocket-Protocol")
  
                      request_handle:logInfo("Lua filter: Checking Sec-WebSocket-Protocol header")
                      
                      if sec_websocket_protocol == nil then
                        request_handle:logInfo("Lua filter: Sec-WebSocket-Protocol header is missing")
                        request_handle:respond({[":status"] = "403"}, "Access denied")
                      else
                        local parts = {}
                        for part in sec_websocket_protocol:gmatch("[^,]+") do
                          table.insert(parts, part:match("^%s*(.-)%s*$"))
                        end
                        
                        local found = false
                        for _, part in ipairs(parts) do
                          if part:match("^Bearer%s") then
                            found = true
                            break
                          end
                        end
                        
                        if not found then
                          request_handle:logInfo("Lua filter: Bearer token not found in Sec-WebSocket-Protocol header")
                          request_handle:respond({[":status"] = "403"}, "Access denied")
                        else
                          request_handle:logInfo("Lua filter: Bearer token found in Sec-WebSocket-Protocol header")
                        end
                      end
                    end
              - name: envoy.filters.http.jwt_authn
                typed_config:
                  "@type": type.googleapis.com/envoy.extensions.filters.http.jwt_authn.v3.JwtAuthentication
                  providers:
                    keycloak:
                      issuer: "<replace with keycloak issuer>"
                      audiences:
                      - "<replace with audience>"
                      remote_jwks:
                        http_uri:
                          uri: "<replace with keycloak jwks_uri>"
                          cluster: keycloak_cluster
                          timeout: 5s
                        cache_duration:
                          seconds: 300
                  rules:
                  - match:
                      prefix: "/"
                    requires:
                      provider_name: "keycloak"
              - name: envoy.filters.http.router
```

Explanation:
- This configuration sets up an Envoy proxy for authentication in a generic environment.
- It includes a Lua script that checks for the presence of a Bearer token in the Sec-WebSocket-Protocol header.
- JWT authentication is configured to validate tokens against a Keycloak server.
- The configuration allows WebSocket upgrades, which is necessary for WebRTC signaling.
- If authentication fails, the request is denied with a 403 status code.

### application-profile.yaml

This application profile provides a generic configuration without authentication or TLS.

### application-profile-wait-ready-envoy.yaml

This application profile includes a startup probe to ensure the application is ready before accepting traffic, using envoy for the readiness check.

Key features:
```yaml
envoy:
  config: |
    node:
      id: node0
      cluster: envoy-cluster
    static_resources:
      listeners:
      - name: webrtc_signaling_listener
        address:
          socket_address:
            address: 0.0.0.0
            port_value: 49200
        filter_chains:
        - filters:
          - name: envoy.filters.network.http_connection_manager
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
              stat_prefix: signaling_http
              codec_type: AUTO
              upgrade_configs:
              - upgrade_type: websocket
              route_config:
                name: local_route
                virtual_hosts:
                - name: local_service
                  domains: ["*"]
                  routes:
                  - match:
                      prefix: "/"
                    route:
                      cluster: service_cluster
              http_filters:
              - name: envoy.filters.http.router
              access_log:
                - name: envoy.access_loggers.stream
                  typed_config:
                    "@type": type.googleapis.com/envoy.extensions.access_loggers.stream.v3.StdoutAccessLog
                    log_format:
                      text_format: |
                        [START_TIME: %START_TIME%]
                        REQUEST_METHOD: %REQ(:METHOD)%
                        PATH: %REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%
                        PROTOCOL: %PROTOCOL%
                        RESPONSE_CODE: %RESPONSE_CODE%
                        RESPONSE_FLAGS: %RESPONSE_FLAGS%
                        BYTES_RECEIVED: %BYTES_RECEIVED%
                        BYTES_SENT: %BYTES_SENT%
                        DURATION: %DURATION%
                        UPSTREAM_HOST: %UPSTREAM_HOST%
                        DOWNSTREAM_REMOTE_ADDRESS: %DOWNSTREAM_REMOTE_ADDRESS%
      - name: health_listener
        address:
          socket_address:
            address: 0.0.0.0
            port_value: 8080
        filter_chains:
        - filters:
          - name: envoy.filters.network.http_connection_manager
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
              stat_prefix: health_check
              codec_type: AUTO
              route_config:
                name: local_route
                virtual_hosts:
                - name: local_service
                  domains: ["*"]
                  routes:
                  - match:
                      prefix: "/health"
                    direct_response:
                      status: 200
                      body:
                        inline_string: "OK"
              http_filters:
              - name: envoy.filters.http.router
      - name: ready_listener
        address:
          socket_address:
            address: 0.0.0.0
            port_value: 8081
        filter_chains:
        - filters:
          - name: envoy.filters.network.http_connection_manager
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
              stat_prefix: ready_check
              codec_type: AUTO
              route_config:
                name: local_route
                virtual_hosts:
                - name: local_service
                  domains: ["*"]
                  routes:
                  - match:
                      prefix: "/ready"
                    direct_response:
                      status: 200
                      body:
                        inline_string: "OK"
              http_filters:
              - name: envoy.filters.http.lua
                typed_config:
                  "@type": type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua
                  inline_code: |
                    local start_time = os.time()
                    function envoy_on_request(request_handle)
                      if os.time() - start_time < 60 then
                        request_handle:respond({[":status"] = "503"}, "Not ready yet")
                      end
                    end
              - name: envoy.filters.http.router
      clusters:
      - name: service_cluster
        connect_timeout: 0.25s
        type: STATIC
        lb_policy: ROUND_ROBIN
        load_assignment:
          cluster_name: service_cluster
          endpoints:
          - lb_endpoints:
            - endpoint:
                address:
                  socket_address:
                    address: 127.0.0.1
                    port_value: 49100  # Forwarding to the stream
startupProbe:
  failureThreshold: 30
  httpGet:
    path: /ready
    port: 8081
  initialDelaySeconds: 20
  periodSeconds: 10
```

Explanation:
- This configuration sets up an Envoy proxy with three listeners:
  1. WebRTC signaling listener on port 49200
  2. Health check listener on port 8080
  3. Readiness check listener on port 8081
- The WebRTC signaling listener is configured to handle WebSocket upgrades and route traffic to the service cluster.
- Detailed access logging is configured for the signaling listener.
- The health check listener responds with a 200 OK status to requests on the "/health" path.
- The readiness check listener uses a Lua script to implement a delay before considering the service ready. It responds with a 503 status for the first 60 seconds after startup.
- A startup probe is configured to check the "/ready" endpoint on port 8081, allowing for a grace period before the service is considered ready to accept traffic.

### application-profile-wait-ready-pending.yaml

This application profile is designed for use with pending versions of the application, incorporating a startup probe that checks if the application is ready.

Key features:
```yaml
podAnnotations:
  nvidia.omniverse.ovas.pod.maxPendingTime: "30"
```

Explanation:
- This configuration sets a maximum pending time of 30 seconds for the pod.
- It's designed to work with the NVIDIA Omniverse application versioning system, allowing for a grace period during startup.

### application-version.yaml

The generic application version contains the container image and container version for the application.

### application.yaml

The generic application file contains a high-level description of the application and what is used to link the profiles and versions together.

## MetalLB

### application-profile-metallb.yaml

This profile provides a configuration for using MetalLB and External-DNS.

Key features:
```yaml
service:
  annotations:
    metallb.universe.tf/address-pool: "<replace with address pool>"
    external-dns.alpha.kubernetes.io/hostname: "<not set - will be set automatically>"
  type: LoadBalancer
```

Explanation:
- This configuration sets up a LoadBalancer service using MetalLB.
- It specifies an address pool for MetalLB to use when assigning IP addresses.
- The `external-dns.alpha.kubernetes.io/hostname` annotation is used to automatically set up DNS records for the service.
- The service type is set to LoadBalancer, which will be handled by MetalLB in on-premises environments.

### application-version.yaml

The MetalLB application version contains the container image and container version for the application.

### application.yaml

The MetalLB application file contains a high-level description of the application and what is used to link the profiles and versions together.

These configurations provide various options for deploying Omniverse applications in different environments, including AWS with different load balancer configurations, generic setups, and MetalLB-based deployments. Each profile and version file can be customized based on specific requirements and infrastructure setups.