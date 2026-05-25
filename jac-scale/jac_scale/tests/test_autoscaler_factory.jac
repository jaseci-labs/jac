"""Unit tests for autoscaler factory + engine selection behavior."""

import unittest.mock;

import from jac_scale.factories.autoscaler_factory { AutoscalerFactory }
import from jac_scale.abstractions.models.autoscaler { AutoscalerSpec, Trigger }


test "autoscaler factory defaults to hpa engine" {
    autoscaler = AutoscalerFactory.create(None, {"namespace": "default"});
    assert autoscaler is not None;
    assert autoscaler.__class__.__name__ == "HPAAutoscaler";
}


test "autoscaler factory creates hpa engine by name" {
    autoscaler = AutoscalerFactory.create("hpa", {"namespace": "default"});
    assert autoscaler is not None;
    assert autoscaler.__class__.__name__ == "HPAAutoscaler";
}


test "autoscaler factory creates keda engine by name" {
    autoscaler = AutoscalerFactory.create("keda", {"namespace": "default"});
    assert autoscaler is not None;
    assert autoscaler.__class__.__name__ == "KEDAAutoscaler";
}


test "autoscaler factory raises for unknown engine" {
    raised = False;
    try {
        AutoscalerFactory.create("nope", {"namespace": "default"});
    } except ValueError as e {
        raised = True;
        assert "Unsupported autoscaler engine" in str(e);
    }
    assert raised , "Expected ValueError for unknown autoscaler engine";
}


test "hpa with non-resource trigger auto-promotes to keda and logs once" {
    logger = unittest.mock.MagicMock();
    spec = AutoscalerSpec(
        target_name="orders",
        namespace="default",
        triggers=[Trigger(type="redis", metadata={"listName": "jobs"})]
    );
    autoscaler = AutoscalerFactory.create(
        "hpa", {"namespace": "default"}, logger, spec
    );
    assert autoscaler.__class__.__name__ == "KEDAAutoscaler";
    logger.info.assert_called_once();
    assert "auto-promot" in str(logger.info.call_args).lower();
}
