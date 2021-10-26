%%%-------------------------------------------------------------------
%% @doc chef_infra_bench top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(chef_infra_bench_sup).

-behaviour(supervisor).

-export([start_link/0]).

-export([init/1]).

-define(SERVER, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%% sup_flags() = #{strategy => strategy(),         % optional
%%                 intensity => non_neg_integer(), % optional
%%                 period => pos_integer()}        % optional
%% child_spec() = #{id => child_id(),       % mandatory
%%                  start => mfargs(),      % mandatory
%%                  restart => restart(),   % optional
%%                  shutdown => shutdown(), % optional
%%                  type => worker(),       % optional
%%                  modules => modules()}   % optional
init([]) ->
    SupFlags = #{strategy => one_for_all,
                 intensity => 0,
                 period => 1},
    %ChildSpecs = [],
    ChildSpecs = [#{id => chef_infra_load_config,
                    start => {chef_infra_load_config, start_link, ["dummy"]},
                    restart => permanent,
                    shutdown => brutal_kill,
                    type => worker,
                    modules => [chef_infra_load_config]}],
    {ok, {SupFlags, ChildSpecs}}.

%% internal functions
