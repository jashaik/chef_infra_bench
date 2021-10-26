-module(chef_infra_load_config).
-behaviour(gen_server).

%% API
-export([
         start_link/1,
         run/0,
         knife_exec/1,
         run_knife_cmd/1
        ]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {log_path,
                current_position = 0,
                total_lines}).

%%% =======================================================
%%% Interface functions
%%% 
%%% =======================================================
start_link(AccessLogPath) ->
    io:format("starting the load config module ~p~n",[""]),
    gen_server:start_link(?MODULE, [AccessLogPath], []).

run() ->
  Res1 = os:cmd("grep \" 404 \" access.log | tail -n 10000 | awk '{ print $6 \" \" $7 }' "),
  List1 = string:tokens(Res1, "\n\""),
  Worker_num = erlang:round(length(List1) / 500),
 % [chef_infra_load_config:knife_exec(lists:sublist(List1, X*Worker_num+1, 500))
  %    || X <- lists:seq(0,Worker_num-1)].
  [spawn(chef_infra_load_config, knife_exec,[lists:sublist(List1, X*Worker_num+1, 500)])
      || X <- lists:seq(0,Worker_num-1)].
  

%%%===================================================================
%%% Gen Server Callbacks
%%%===================================================================
init([AccessLogPath]) ->
    process_flag(trap_exit, true),
    erlang:send_after(5000, self(), start_reading),
    {ok, #state{log_path = AccessLogPath, total_lines = 10001 }}.

handle_call(_, _From, State) ->
  {noreply, State}.

handle_cast({send_event_to_mq, Event,Topic}, State) ->
  %zataas_kafka_brod_if:send(Event,Topic),
  {noreply, State};

handle_cast(stop, State) ->
    {stop, normal, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(start_reading, #state{log_path = Path} = State) ->
    Res1 = os:cmd("grep \" 404 \" access.log | tail -n 10000 | awk '{ print $6 \" \" $7 }' "),
    List1 = string:tokens(Res1, "\n\""),
  Worker_num = erlang:round(length(List1) / 500),
  [spawn(chef_infra_load_config, knife_exec,[lists:sublist(List1, X*500+1, 500)])
      || X <- lists:seq(0,Worker_num-1)],
  %io:format("The res - ~p~n",[string:tokens(Res1, "\n\"")]),
  erlang:send_after(120000, self(), start_reading),
  {noreply, State};

handle_info(_, State) ->
  {noreply, State}.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

terminate(normal, _State) ->
  ok.

knife_exec(SubList) ->
  %io:format("knife exec - ~p~n",[length(SubList)]),
  %[spawn(chef_infra_load_config, run_knife_cmd,[X])|| X <- SubList].
  [chef_infra_load_config:run_knife_cmd(X)|| X <- SubList].

run_knife_cmd(URL) ->
  Command = "knife raw -m " ++ URL,
  Port = open_port({spawn, Command}, [stream, in, eof, hide, exit_status]),
  get_data(Port, []).

get_data(Port, Sofar) ->
    receive
    {Port, {data, Bytes}} ->
        lager:info("Received - ~p", [Bytes]),
        get_data(Port, [Sofar|Bytes]);
    {Port, eof} ->
        Port ! {self(), close},
        receive
        {Port, closed} ->
            true
        end,
        receive
        {'EXIT',  Port,  _} ->
            ok
        after 1 ->              % force context switch
            ok
        end,
        ExitCode =
            receive
            {Port, {exit_status, Code}} ->
                Code
        end,
        {ExitCode, lists:flatten(Sofar)}
    end.
