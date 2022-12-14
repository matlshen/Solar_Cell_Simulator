%% Define cell constant values
clear
clc

eta = 2;        % Set - Ideality factor
Is = 0.005;     % TBD - Reverse bias saturation current
R = 0.003;      % TBD - Series resistance
IoptMax = 2;    % TBD - Maximum optical current
T = 303;        % Set - Temperature (30C)
theta = 0;
phi = 0;

testCell = SolarCell.CreateCell("testCell");
testCell.eta = eta;
testCell.Is = Is;
testCell.R = R;
testCell.IoptMax = IoptMax;
testCell.T = T;
testCell.theta = theta;
testCell.phi = phi;
testCell2 = SolarCell.CreateCell("testCell2", eta, Is, R, IoptMax, T, theta, phi);

testModule = Module.CreateModule("testModule");
testModule.AddCell(testCell);
testModule.AddCell(testCell2);
testModule.bypassPresent = 1;

testModule.PlotMPP(1);
[V, I, P] = testModule.GetMPP(1)

%% Test Plot single cell
testCell.PlotMPP(0.5);
[V, I, P] = testCell.GetMPP(0.5)