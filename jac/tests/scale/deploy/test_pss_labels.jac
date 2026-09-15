"""jac-scale must be able to upgrade a namespace it labeled itself.

The deploy stamps enforce=baseline on any namespace lacking an enforce label,
then the observability step refused to touch a namespace that already carried
one, so the privileged upgrade the hostPath DaemonSets need could never fire on
a namespace jac-scale created. An operator's own label must still be respected.
"""

import from jaclang.scale.deploy.target.kubernetes.utils.kubernetes_utils {
    default_pss_labels,
    privileged_pss_labels,
    PSS_ENFORCE_LABEL,
    PSS_SOURCE_LABEL,
    PSS_WARN_LABEL
}


test "the default labels record that jac-scale set the enforce level" {
    labels = default_pss_labels();
    assert labels[PSS_ENFORCE_LABEL] == "baseline";
    assert labels[PSS_WARN_LABEL] == "restricted";
    assert labels[PSS_SOURCE_LABEL] == "baseline";
}


test "an unlabeled namespace is upgraded to privileged" {
    patch = privileged_pss_labels({});
    assert patch == {PSS_ENFORCE_LABEL: "privileged", PSS_SOURCE_LABEL: "privileged"};
}


test "the baseline jac-scale set on this namespace is upgraded, not refused" {
    patch = privileged_pss_labels(default_pss_labels());
    assert patch is not None , "jac-scale must be able to overwrite its own default";
    assert patch[PSS_ENFORCE_LABEL] == "privileged";
    assert patch[PSS_SOURCE_LABEL] == "privileged" , "the marker follows the value";
}


test "an operator's own enforce label is left alone" {
    assert privileged_pss_labels({PSS_ENFORCE_LABEL: "baseline"}) is None;
    assert privileged_pss_labels({PSS_ENFORCE_LABEL: "restricted"}) is None;
}


test "a namespace whose baseline came from somewhere else is left alone" {
    existing = {PSS_ENFORCE_LABEL: "restricted", PSS_SOURCE_LABEL: "baseline"};
    assert privileged_pss_labels(existing) is None;
}


test "a namespace already privileged needs no patch and no warning" {
    assert privileged_pss_labels({PSS_ENFORCE_LABEL: "privileged"}) == {};
}


test "a second deploy of the same namespace is a no-op" {
    first = privileged_pss_labels(default_pss_labels());
    settled = {** default_pss_labels(), ** first};
    assert privileged_pss_labels(settled) == {} , "upgrading twice must not re-patch";
}
