graph layers {
    layer app { app; }
    layer bound { bound; }
    layer byllm { by; }
    layer codec { codec; }
    layer cpython_space { cpython_space; }
    layer crossing { crossing; }
    layer desktop { desktop; }
    layer graphs { graph; }
    layer llm { llm; }
    layer node_space { node_space; }
    layer plan { plan; }
    layer remote { remote; }
    layer server { server; }
    layer sqlfile { sqlfile; }
    layer window { window; }
    """What no wire joins to the rest."""
    layer apart { jsx; }
}

graph import {
    edge Bound: bound --> app | llm | remote | server;
    edge By: byllm --> llm;
    edge Codec: codec --> bound | byllm | crossing | graphs | plan | remote | server;
    edge Graph: graphs --> app | remote | server | sqlfile;
    edge Plan: plan --> app | remote | server;
    edge Remote: remote --> app | cpython_space | node_space | server;
    edge Server: server --> app | cpython_space | desktop | node_space;
    edge Sqlfile: sqlfile --> app;
    edge Window: window --> desktop;

    bound ++> app | llm | remote | server { bound }
    by ++> llm {
        By,
        ByCall,
        ByChoice,
        ByChooser,
        ByError,
        ByEvent,
        ByEventKind,
        ByStreams,
        ByTool,
        ByUsage,
    }
    codec ++> [
        bound { decode },
        by { decode, encode },
        crossing { CodecError, declares_reports, decode },
        graph { CodecError, decode_object, encode_object, fill_object, shape_of },
        plan { decode },
        remote { CodecError, declares_reports, decode, encode },
        server { decode, encode },
    ]
    plan ++> [
        app { Page, Window, data_dir, env_name, keep_arrangement, plan, remote_url, space_code },
        remote { remote_url },
        server { plan, space_code },
    ]
    graph ++> [
        app { DataError, Store, StoreCodec, graph_open, store_in_turn },
        remote { StoreConflict, commit, current_caller, enter_caller, kept_call },
        server { kept_call },
        sqlfile { DataError },
    ]
    sqlfile ++> app { upgrades_made }
    remote ++> [
        app {
            CannotListen,
            Claim,
            Request,
            Response,
            Tick,
            answer_stream,
            carried,
            carry_stream,
            forward_remote,
            on_loop,
            open_stream,
            pull_stream,
            transport,
        },
        cpython_space { carry_in_process },
        node_space { carry_in_process, loop_serving, on_loop },
        server { Request, Response, answer, endpoint_named, json_values, reply_fail, settle },
    ]
    server ++> [
        app {
            auth_caller,
            auth_route,
            deployment_signed,
            json_fail,
            json_ok,
            limited,
            open_auth,
            ran_job,
            route_answer,
            route_of,
            routes,
            Scheduled,
            scheduled,
            space_host,
            start_schedule,
            static_file,
            window_host,
        },
        cpython_space { Scheduled, SpaceHost, register_space_host },
        desktop { WindowHost, register_window_host },
        node_space { Scheduled, SpaceHost, register_space_host },
    ]
    window ++> desktop { run_window }
}
