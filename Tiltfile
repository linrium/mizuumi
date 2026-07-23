KIND_CONFIG = './infra/k8s/kind.yaml'
KIND_CLUSTER_NAME = 'mizuumi'
AUTH_DIR = './packages/auth'

allow_k8s_contexts('kind-%s' % KIND_CLUSTER_NAME)

local_resource(
    name='kind-cluster',
    cmd='./scripts/setup-kind.sh "%s"' % KIND_CLUSTER_NAME,
    deps=[
        KIND_CONFIG,
        './scripts/setup-kind.sh',
    ],
    labels=['infra'],
    trigger_mode=TRIGGER_MODE_MANUAL,
    auto_init=False,
)

local_resource(
    name='auth',
    cmd='%s/scripts/install.sh' % AUTH_DIR,
    deps=[
        '%s/scripts/install.sh' % AUTH_DIR,
        '%s/manifests/admin.yaml' % AUTH_DIR,
        '%s/manifests/postgres.yaml' % AUTH_DIR,
        '%s/manifests/keycloak.yaml' % AUTH_DIR,
    ],
    resource_deps=['kind-cluster'],
    labels=['auth'],
    trigger_mode=TRIGGER_MODE_MANUAL,
    auto_init=False,
)
