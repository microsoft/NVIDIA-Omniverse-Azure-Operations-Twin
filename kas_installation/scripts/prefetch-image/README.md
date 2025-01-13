# Prefetch-Image

Simple bash script to prefetch image(s) in a target OVC environment via daemonset, then clean up the daemonset when finished.

## Usage

```
./prefetch-image {image-name}
```

1. Populate `applications.json` with target images and tags:

    ```
    {
        "applications": {
            "my-usd-app": {    # name must be lowercase and use hyphens instead of spaces
                "image": "nvcr.io/nvidia/omniverse/my-usd-app",
                "tag": "0.1.0"
            }
        }
    }
    ```

1. Switch your kube context to your target cluster
1. `./prefetch-image.sh {application-name}`
    - Specify a single application name (e.g. 'usd-explorer' matching the definition in `applications.json` to prefetch just that image.
