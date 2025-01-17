function [g,Value,Deriv] = avoidfunction(centers,radius)
% [g, data] = avoidfunction(centers,radius)
% Solves for spatial gradients of the value function to avoid a set of 
% cylindrical obstacles with given centers and fixed radius. 
%
% Normally you would apply the optimal safe control on the boundary where 
% You would do this by finding the argmax of the hamiltonian.  This means 
% taking the inner product between the spatial gradients of the value 
% function (Deriv) and the dynamics of the system. When maximizing over 
% that you will find the optimal safe control.
%
% for a particular state in your dynamic system dynSys, this means:
%     %find deriv at exactly x
%     deriv = eval_u(g, Deriv, dynSys.x); 
%
%     % plug into function for optimal control given dynamics
%     u = dynSys.optCtrl(tau(tEarliest), dynSys.x, deriv, uMode);
%
%     % plug that optimal control into the system
%     dynSys.updateState(u, dtSmall, dynSys.x);
%
% However, ANY control such that that inner product (the hamiltonian) is
% non-negative will be a sufficient safe control.  You just want to make 
% sure the resulting hamiltonian is not negative on the boundary.
%
% For questions, contact Sylvia Herbert, sherbert@ucsd.edu
%
% ----- How to use this function -----
%
% Inputs:
%   centers         - (cell) list of centers of obstacles. Example:
%                       centers = {[0,0], [1,1]} would create two
%                       obstacles with centers at positions (0,0) and (1,1)
%   radius          - (double) radius of all obstacles. Can easily turn
%                       into a list of varying radii if you prefer.
%
% Outputs:
%   g               - (struct) grid over state space
%   Value           - (matrix) value function defined over that grid.
%   Deriv           - (cell) spatial gradients of the value function 
%                       defined over that grid.

if nargin < 1
    centers = {[-2,-2], [-0.5, -0.5], [2, 3], [4,-3]};
end

if nargin <2
    radius = 1;
end

%% Grid
grid_min = [-5; -5; -pi]; % Lower corner of computation domain
grid_max = [5; 5; pi];    % Upper corner of computation domain
N = [50; 50; 50];         % Number of grid points per dimension
pdDims = 3;               % 3rd dimension is periodic
g = createGrid(grid_min, grid_max, N, pdDims);
% Use "g = createGrid(grid_min, grid_max, N);" if there are no periodic
% state space dimensions

%% target set

data0 = shapeCylinder(g, 3, [centers{1},0], radius);
for ii = 2:length(centers)
   newobs = shapeCylinder(g, 3, [centers{ii},0], radius);
   data0 = shapeUnion(data0,newobs);
end


%% time vector
t0 = 0;
tMax = 10;
dt = 0.05;
tau = t0:dt:tMax;

% stop the computation once it converges
HJIextraArgs.stopConverge = 1;
HJIextraArgs.convergeThreshold = .01;

%% problem parameters

% input bounds
speed = 1;
wMax = 1;

% control trying to min or max value function?
uMode = 'max';

%% Pack problem parameters

% Define dynamic system
% obj = DubinsCar(x, wMax, speed, dMax)
dCar = DubinsCar([0, 0, 0], wMax, speed); %do dStep3 here

% Put grid and dynamic systems into schemeData
schemeData.grid = g;
schemeData.dynSys = dCar;
schemeData.accuracy = 'high'; %set accuracy
schemeData.uMode = uMode;

%% Visualization


HJIextraArgs.visualize.plotColorVS0 = 'r';
HJIextraArgs.visualize.valueSet = 1;
HJIextraArgs.visualize.initialValueSet = 1;
HJIextraArgs.visualize.figNum = 1; %set figure number
HJIextraArgs.visualize.deleteLastPlot = true; %delete previous plot as you update
HJIextraArgs.visualize.viewAxis = ...
    [grid_min(1) grid_max(1)...
    grid_min(2) grid_max(2) ...
    grid_min(2) grid_max(3)];

%% Compute value function
%[data, tau, extraOuts] = ...
% HJIPDE_solve(data0, tau, schemeData, minWith, extraArgs)
[Value, tau2, ~] = ...
  HJIPDE_solve(data0, tau, schemeData, 'minVOverTime', HJIextraArgs);

Deriv = computeGradients(g, Value);

end