%%%-------------------------------------------------------------------
%% @doc chef_infra_bench public API
%% @end
%%%-------------------------------------------------------------------

-module(chef_infra_bench_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    chef_infra_bench_sup:start_link().

stop(_State) ->
    ok.

%% internal functions
