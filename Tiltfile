KIND_CONFIG = './infra/k8s/kind.yaml'
KIND_CLUSTER_NAME = 'mizuumi'

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