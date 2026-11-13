impl build_services -> BuildServices {
    try {
        provider = importlib.import_module('jaclang.compiler.driver.build_services');
    } except ModuleNotFoundError as error {
        if error.name
            not in (
                'jaclang.compiler',
                'jaclang.compiler.driver',
                'jaclang.compiler.driver.build_services'
            ) {
            raise;
        }
        raise RuntimeError(
            'This application contains executable artifacts; compiler services are not installed.'
        ) from error;
    }
    return provider.CompilerBuildServices();
}
