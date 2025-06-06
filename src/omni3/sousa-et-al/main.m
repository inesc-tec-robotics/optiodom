close all
clear
clc

%% INITIALIZATION

visualize = true;

% Dataset filenames:
% - Lin et al  : any dataset.
% - Sousa et al: any dataset.
Dataset.filenames = {
  '../../../data/omni3/circular/221220201643/221220201643',
  '../../../data/omni3/circular/221220201701/221220201701',
  '../../../data/omni3/circular/221220201716/221220201716',
  '../../../data/omni3/circular/221220201722/221220201722',
  '../../../data/omni3/circular/221220201726/221220201726',
  '../../../data/omni3/circular/221220201730/221220201730',
  '../../../data/omni3/circular/221220201750/221220201750',
  '../../../data/omni3/square/221220201934/221220201934',
  '../../../data/omni3/square/221220201953/221220201953',
  '../../../data/omni3/joystick/211220201842/211220201842',
  '../../../data/omni3/joystick/221220202228/221220202228',
  '../../../data/omni3/joystick/221220202235/221220202235'
};
Dataset.metadata  = '../../../data/omni3/circular/221220201643/221220201643_metadata.csv';
Dataset.N    = length(Dataset.filenames);
Dataset.data = cell(1,Dataset.N);

% Method parameters:
% some methods require specific parameters for their execution
Method.name       = 'sousa';
Method.sampleDist = [0.5];
% - options:
%   > type         : 'rprop+', 'rprop-', 'irprop+', 'irprop-'
%   > nplus        : rprop acceleration parameter
%   > nminus       : rprop deceleration parameter
%   > maxvar       : maximum parameters variation
%   > minvar       : minimum parameters variation
%   > maxiter      : maximum iterations
%   > miniter      : minimum iterations
%   > minvarbetiter: minimum variation to break algorithm
%   > numiterminavg: number of iterations to compute the average
Method.options.type   = 'irprop-';
Method.options.nplus  = [ 1.005 , 1.005 , 1.005 , 1.005 ];
Method.options.nminus = [ 0.500 , 0.500 , 0.500 , 0.500 ];
Method.options.maxvar = [ 0.00025 , 0.00025 , 0.00025 , 0.00025 ];
Method.options.minvar = [ 0.00001 , 0.00001 , 0.00001 , 0.00001 ];
Method.options.maxiter = 1000;
Method.options.miniter = 50;
Method.options.minvarbetiter = 0.0001;
Method.options.numiterminavg = 20;
% - exclude worse runs
Method.options.excludeRuns = [];
% Method. ...

% Robot parameters:
[RobotParam] = readRobotParametersMetadata(Dataset.metadata);
% ... you can change the robot parameters after reading them from a metadata csv file


% Agregated data
t    = {};
Odo  = {};
XOdo = {};
XGt  = {};
XErr = {};
XOdoCal = {};
XErrCal = {};
iSamples = {};
Filenames = {};

%% DATA PROCESSMENT
k = 1;
auxExcludeRuns = Method.options.excludeRuns;
for i=1:Dataset.N
  Dataset.data{i}.parameters = readDatasetParameters(strcat(Dataset.filenames{i},'_metadata.csv'));

  for j=1:Dataset.data{i}.parameters.N

    [ Dataset.data{i}.parameters.Tsampling , ...
      Dataset.data{i}.numSamples{j}        , ...
      Dataset.data{i}.time{j} , ...
      Dataset.data{i}.XGt{j}  , ...
      Dataset.data{i}.Odo{j}  ] = loadData(strcat(Dataset.filenames{i},sprintf('_run-%02d.csv', j)),RobotParam);
    
    [Dataset.data{i}.XOdo{j},Dataset.data{i}.iSamples{j}] = simulateRobot_omni3( ...
      Dataset.data{i}.XGt{j}(1,:)                   , ...
      Dataset.data{i}.Odo{j}                        , ...
      Dataset.data{i}.parameters.Tsampling          , ...
      RobotParam                                    , ...
      Method.sampleDist);
    
    Dataset.data{i}.XErr{j} = Dataset.data{i}.XGt{j} - Dataset.data{i}.XOdo{j};
    
    % Agregated data
    if (~isempty(auxExcludeRuns))
      if (sum(k == auxExcludeRuns) > 0)
        auxExcludeRuns (k == auxExcludeRuns) = [];
        auxExcludeRuns = auxExcludeRuns - 1;
        runok = false;
      else
        runok = true;
      end
    else
      runok = true;
    end
    if (runok)
      Filenames{k} = strcat(Dataset.filenames{i},sprintf('_run-%02d.csv', j));
      t{k}    = Dataset.data{i}.time{j};
      XGt{k}  = Dataset.data{i}.XGt{j};
      Odo{k}  = Dataset.data{i}.Odo{j};
      XOdo{k} = Dataset.data{i}.XOdo{j};
      XErr{k} = Dataset.data{i}.XErr{j};
      iSamples{k} = Dataset.data{i}.iSamples{j};
      k = k+1;
    end
  end
end

%% METHOD: SOUSA ET AL.
% - Lin et al  : any dataset.
% - Sousa et al: any dataset.

% Evaluation measures
Method.results.uncalibrated = computeEvaluationMeasures(XErr);

% Calibration procedure
[ RobotEstParam                       , ...
  Method.results.optimization.cost    , ...
  Method.results.optimization.costSim , ...
  Method.results.optimization.numIterations    , ...
  Method.results.optimization.historyRobotParam] = Rprop_omni3( ...
    RobotParam     , ...
    XGt            , ...
    Odo            , ...
    iSamples       , ...
    Method.options   ...
  );

%% SIMULATE CALIBRATED ROBOT

% Odometry data
k = 1;
auxExcludeRuns = Method.options.excludeRuns;
for i=1:Dataset.N
  for j=1:Dataset.data{i}.parameters.N    
    [Dataset.data{i}.XOdoCal{j},~] = simulateRobot_omni3( ...
      Dataset.data{i}.XGt{j}(1,:)                      , ...
      Dataset.data{i}.Odo{j}                           , ...
      Dataset.data{i}.parameters.Tsampling             , ...
      RobotEstParam                                    , ...
      Method.sampleDist);
    
    Dataset.data{i}.XErrCal{j} = Dataset.data{i}.XGt{j} - Dataset.data{i}.XOdoCal{j};
    
    % Agregated data
    if (~isempty(auxExcludeRuns))
      if (sum(k == auxExcludeRuns) > 0)
        auxExcludeRuns (k == auxExcludeRuns) = [];
        auxExcludeRuns = auxExcludeRuns - 1;
        runok = false;
      else
        runok = true;
      end
    else
      runok = true;
    end
    if (runok)
      XOdoCal{k} = Dataset.data{i}.XOdoCal{j};
      XErrCal{k} = Dataset.data{i}.XErrCal{j};
      k = k+1;
    end
  end
end

% Evaluation measures
Method.results.calibrated = computeEvaluationMeasures(XErrCal);


%% VISUALIZATION
main_visualizationSimplex

if (visualize)
  main_visualization
end