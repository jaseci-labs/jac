"""Emailer mixin implementation: build the emailer once at server startup."""

import from jac_scale.config_loader { get_scale_config }
import from jac_scale.factories.emailer_factory { create as create_emailer }

impl JacAPIServerEmailer.setup_emailer -> Emailer | None {
    if self._emailer is not None {
        return self._emailer;
    }
    cfg = get_scale_config().get_emailer_config();
    self._emailer = create_emailer(cfg);
    if self._emailer is not None {
        logger.debug(
            "Emailer initialised: provider=%s, ready=%s",
            cfg.get('provider', ''),
            self._emailer.is_ready()
        );
    }
    return self._emailer;
}

impl JacAPIServerEmailer.get_emailer -> Emailer | None {
    return self._emailer;
}
