# Prefetch-Image

Simple bash script to prefetch image(s) in a target deployment environment via daemonset, then clean up the daemonset when finished.
Prefetching the images will help with startup time of a streaming session.

## Usage

```
./prefetch-image {image-name}
```

1. In `prefetch-image.yaml` validate that the node selector is correct for the given cluster. The deamonset needs to run on the hosts that will host the GPU. Any Kubernetes label that target those types of hosts can be used

2. Populate `applications.json` with target images and tags:

    ```
    {
        "applications": {
            "usd-viewer": {    # name must be lowercase and use hyphens instead of spaces
                "image": "nvcr.io/nvidia/omniverse/usd-viewer",
                "tag": "0.2.0"
            }
        }
    }
    ```

3. Switch your kube context to your target cluster
4. `./prefetch-image.sh {application-name}`
    - Specify a single application name (e.g. 'usd-viewer' matching the definition in `applications.json` to prefetch just that image.
    - `{application-name}` is optional. If not set all applications will be warmed up.
