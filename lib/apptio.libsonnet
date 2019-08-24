local kube = import 'kube.libsonnet';

// helper library for k8s in apptio

{
  //--------- RBAC

  // rolerefs for pre-defined roles, to use in rolebindings (these are invisible)
  roleref_admin_clusterrole:: {
    kind: 'ClusterRole',
    metadata: {
      name: 'admin',
    },
  },
  roleref_clusteradmin_clusterrole:: {
    kind: 'ClusterRole',
    metadata: {
      name: 'cluster-admin',
    },
  },
  roleref_view_clusterrole:: {
    kind: 'ClusterRole',
    metadata: {
      name: 'view',
    },
  },

  namespace(name): { metadata+: { namespace: name } },

  personal_namespace_binding(user, roleref, nameformat):
    // A binding in the user's personal namespace
    kube.RoleBinding(std.format(nameformat, user)) {
      roleRef_: roleref,
      subjects: [
        {
          kind: 'User',
          name: std.format('%s@apptio.com', user),
          apiGroup: 'rbac.authorization.k8s.io',
        },
      ],
    } + $.namespace(user),

  usergroups_to_namespace_binding(groups, users, roleref, namespace, nameformat='%s_rolebinding'):
    kube.RoleBinding(std.format(nameformat, namespace)) {
      local u_subject(user) = {
        kind: 'User',
        name: std.format('%s@apptio.com', user),
        apiGroup: 'rbac.authorization.k8s.io',
      },
      local g_subject(group) = {
        kind: 'Group',
        name: group,
        apiGroup: 'rbac.authorization.k8s.io',
      },
      roleRef_: roleref,
      subjects: std.map(u_subject, users) + std.map(g_subject, groups),
    } + $.namespace(namespace),

  usergroups_to_clusterrolebinding(groups, users, roleref, name):
    kube.ClusterRoleBinding(name) {
      local g_subject(group) = {
        kind: 'Group',
        name: group,
        apiGroup: 'rbac.authorization.k8s.io',
      },
      local u_subject(user) = {
        kind: 'User',
        name: std.format('%s@apptio.com', user),
        apiGroup: 'rbac.authorization.k8s.io',
      },
      roleRef_: roleref,
      subjects: std.map(u_subject, users) + std.map(g_subject, groups),
    },

  //--------- Secrets/Sealed Secrets

  // Pass in encrypted data structure as "data"
  // To encrypt normal secret, and extract data: kubeseal < mysecret.json | jq .spec.encryptedData
  SealedSecret(name): {
    local this = self,
    apiVersion: 'bitnami.com/v1alpha1',
    kind: 'SealedSecret',
    metadata: {
      name: name,
    },
    spec: {
      encryptedData: this.data,
    },
    data:: {},
  },

  MeteringReport(name, namespace='metering'): {
    apiVersion: 'metering.openshift.io/v1alpha1',
    kind: 'Report',
    metadata: {
      name: name,
      namespace: namespace,
    },
    spec: error 'Must specify report spec',
  },

  BindPSPToAllServiceAccounts(clusterRole, namespace): kube.RoleBinding(clusterRole) {
    local allServiceAccounts = {
      kind: 'Group',
      apiGroup: 'rbac.authorization.k8s.io',
      name: 'system:serviceaccounts',
    },
    metadata+: { namespace: namespace },
    roleRef+: {
      kind: 'ClusterRole',
      name: clusterRole,
    },
    subjects: [
      allServiceAccounts,
    ],
  },

  BindPSPToServiceAccount(clusterRole, account, namespace): kube.RoleBinding(clusterRole) {
    local serviceAccount = {
      kind: 'ServiceAccount',
      namespace: namespace,
      name: account,
    },
    metadata+: { namespace: namespace },
    roleRef+: {
      kind: 'ClusterRole',
      name: clusterRole,
    },
    subjects: [
      serviceAccount,
    ],
  },

  // Get K8S minor version
  K8SMinorVersion(version):: std.parseInt(std.split(version, '.')[1]),

  ServiceMonitor(name, namespace, port='8085', interval='30s', joblabel='app'): {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata: {
      labels: {
        'k8s-app': name,  // the label name (k8s-app) must match the service monitor selector in the prometheus resource
      },
      name: name,
      namespace: namespace,
    },
    // the rest of the spec needs to be merged in
    spec: {
      jobLabel: 'app',
      endpoints: [
        {
          interval: interval,
          targetPort: std.parseInt(port),
        },
      ],
      selector: {
        matchLabels: {
          app: name,
        },
      },
    },
  },

  ArgoApp(name, appnamespace, namespace, cluster, autosync=true): {
    apiVersion: 'argoproj.io/v1alpha1',
    kind: 'Application',
    metadata: {
      name: std.strReplace(name, '_', '-'),
      namespace: namespace,
    },
    spec: {
      [if autosync then 'syncPolicy']+: {
        automated: {
          prune: false,
          selfHeal: false,
        },
      }, 
      destination: {
        server: 'https://kubernetes.default.svc',
        namespace: appnamespace,
      },
      project: 'kr8',
      source: {
        path: 'generated/' + cluster + '/' + name,
        repoURL: 'git@git.dapt.to:techops/kr8-configs.git',
      },
    },
  },

}
