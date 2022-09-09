%% SolarCell Class
% Defines a single solar cell
% Stores IV characteristics of cell in a matrix

classdef SolarCell < handle

    properties
        
        id              % Identifier for cell object

        eta             % Ideality factor
        Is              % Reverse-bias saturation current
        R               % Series resistance
        IoptMax         % Optical current in full light
        T               % Cell temperature
        theta           % Elevation angle (0 when flat)
        phi             % Roll angle (0 when flat)

        isSelected = 0      % Cell is selected in GUI
        parentModuleId      % ID of module cell belongs to
        fullyDefined = 0    % All parameters are defined
        viMatrix            % VI Matrix for storing VI curve

    end

    methods

        % Use setter functions to ensure object knows it's defined
        function set.eta(obj, eta)
            obj.eta = eta;
            obj.IsFullyDefined;
        end
        function set.Is(obj, Is)
            obj.Is = Is;
            obj.IsFullyDefined;
        end
        function set.R(obj, R)
            obj.R = R;
            obj.IsFullyDefined;
        end
        function set.T(obj, T)
            obj.T = T;
            obj.IsFullyDefined;
        end
        function set.IoptMax(obj, IoptMax)
            obj.IoptMax = IoptMax;
            obj.IsFullyDefined;
        end
        function set.theta(obj, theta)
            obj.theta = theta;
            obj.IsFullyDefined;
        end
        function set.phi(obj, phi)
            obj.phi = phi;
            obj.IsFullyDefined;
        end

        % Import VI matrix from file
        function ImportMatrix(obj, filename)
            obj.viMatrix = readmatrix("CurveData/" + filename);
        end
        
        % Returns cell current given voltage and light intensity
        function I = GetCurrent(obj, V, li, sElevation, sAzimuth)
            if obj.fullyDefined
                effLi = obj.ComputeEffLi(li, sElevation, sAzimuth);
                [~, idx] = min(abs(obj.viMatrix(obj.liIndex(effLi), :) - V));
                I = obj.IndexCurrent(idx);
            else
                error('Cell must be fully defined');
            end
        end

        % Returns cell voltage given current and light intensity
        function V = GetVoltage(obj, I, li, sElevation, sAzimuth)
            if obj.fullyDefined
                effLi = obj.ComputeEffLi(li, sElevation, sAzimuth);
                V = obj.viMatrix(obj.liIndex(effLi), obj.CurrentIndex(I));
            else
                error('Cell must be fully defined');
            end
        end

        % Returns maximum effective Iopt given angle and light intensity
        function MaxIopt = GetMaxIopt(obj, li)
            multiplier = cosd(obj.theta) * cosd(obj.phi) * li;
            MaxIopt = multiplier * obj.IoptMax;
        end

        % Returns open-circuit voltage based on light intensity
        function Voc = GetVoc(obj, li, sElevation, sAzimuth)
            if obj.fullyDefined
                Voc = obj.GetVoltage(0, li, sElevation, sAzimuth);
            else
                error('Cell must be fully defined');
            end
        end

        % Returns short-circuit current based on light intensity
        function Isc = GetIsc(obj, li, sElevation, sAzimuth)
            if obj.fullyDefined
                Isc = obj.GetCurrent(0, li, sElevation, sAzimuth);
            else
                error('Cell must be fully defined');
            end
        end

        % Returns power given voltage and light intensity
        function P = GetPowerV(obj, V, li, sElevation, sAzimuth)
            if obj.fullyDefined
                P = V .* obj.GetCurrent(V, li, sElevation, sAzimuth);
                P = P .* ~(isinf(P));
            else
                error('Cell must be fully defined');
            end
        end

        % Returns power given current and light intensity
        function P = GetPowerI(obj, I, li, sElevation, sAzimuth)
            if obj.fullyDefined
                P = I .* obj.GetVoltage(I, li, sElevation, sAzimuth);
                P = P .* ~(isinf(P));
            else
                error('Cell must be fully defined');
            end
        end

        % Returns electrical parameters at the maximum power point
        function [Vmpp, Impp, Pmpp] = GetMPP(obj, li, sElevation, sAzimuth)
            if obj.fullyDefined
                Impp = fminbnd(@(I)obj.GetPowerI(I, li, sElevation, sAzimuth) * (-1), 0, obj.IoptMax);
                Vmpp = obj.GetVoltage(Impp, li, sElevation, sAzimuth);
                Pmpp = Impp * Vmpp;
            else
                error('Cell must be fully defined');
            end
        end

        % Sets light intensity given absolute light intensity and angle of
        % sun relative to cell
        function effLi = ComputeEffLi(obj, li, sZenith, sAzimuth)
            % [NorthDistance EastDistance Altitude]
            sunVector = [sind(sZenith)*cosd(sAzimuth) sind(sZenith)*sind(sAzimuth) cosd(sZenith)];
            cellNormal = [-sind(obj.theta) sind(obj.phi) cosd(obj.theta)];
            cosIncidence = dot(sunVector, cellNormal);
            effLi = li * cosIncidence;
        end

%         % Plot VI curve
%         function PlotVI(obj, li)
%             I = linspace(-1, 10, 1101);
%             y = obj.viMatrix(obj.liIndex(li), :);
% 
%             hold on
%             title('VI Characteristics of ' + obj.id)
%             plot(I, y);
%             plot([0 0], ylim, 'k-')         % plot y-axis
%             plot(xlim, [0 0], 'k-')         % plot x-axis
%             xlabel('Currnet (A)')
%             ylabel('Voltage (V)')
%             hold off
%         end
%
%         % Plot IV curve
%         function PlotIV(obj, li)
%             V = obj.viMatrix(obj.liIndex(li), :);
%             I = linspace(-1, 10, 1101);
% 
%             hold on
%             title('IV Characteristics of ' + obj.id)
%             plot(V, I);
%             plot([0 0], ylim, 'k-')         % plot y-axis
%             plot(xlim, [0 0], 'k-')         % plot x-axis
%             xlabel('Voltage (V)')
%             ylabel('Currnet (A)')
%             hold off
%         end
% 
%         % Plot MPP curve with IV curve
%         function PlotMPP(obj, li)
%             V = obj.viMatrix(obj.liIndex(li), :);
%             I = linspace(-1, 10, 1101);
%             P = obj.GetPowerI(I, li);
%             [Vmpp, Impp, ~] = obj.GetMPP(li);
% 
%             hold on
%             title('IV Characteristics of ' + obj.id)
% 
%             yyaxis left
%             plot(V, I);                     % Plot current as a function of voltage
%             plot([Vmpp Vmpp], ylim, 'r-')   % plot MPP voltage
%             plot(xlim, [Impp Impp], 'r-')   % plot MPP current
%             plot([0 0], ylim, 'k-')         % plot y-axis
%             plot(xlim, [0 0], 'k-')         % plot x-axis
%             xlabel('Voltage (V)')
%             ylabel('Currnet (A)')
% 
%             yyaxis right
%             plot(V, P)                      % plot power as a function of voltage
%             ylabel('Power (W)')
%             hold off
%         end

    end

    methods (Access = private)

        % Tests if cell is fully defined and sets status parameter
        % Generates and exports VI matrix if cell is fully defined (yet to
        % be implemented)
        function obj = IsFullyDefined(obj)
            if ~isempty(obj.eta) && ~isempty(obj.Is) && ~isempty(obj.IoptMax) &&...
                    ~isempty(obj.T) && ~isempty(obj.theta) && ~isempty(obj.phi)
                obj.fullyDefined = 1;
                obj.GenerateMatrix;
            else
                obj.fullyDefined = 0;
            end
        end

        % Function for generating VI matrix
        function GenerateMatrix(obj)
            if obj.fullyDefined
                ID = linspace(-1, 10, 1101);        % Current points for horizontal axis
                li = linspace(0, 1, 101).';         % Light intensity points for vertical axis
                IoptEff = li * obj.IoptMax;   % Effective optical current
                multiplier = obj.eta * (obj.T / 11586);
                log_term = log(((IoptEff - ID) / obj.Is) + 1);
                series_r_drop = ID * obj.R;
                obj.viMatrix = multiplier * log_term - series_r_drop;

                obj.viMatrix = obj.viMatrix ./ (imag(log_term) == 0);   % Handle undefined logs
            else
                error('Cell must be fully defined');
            end
        end

        % Export viMatrix as csv file
        function ExportMatrix(obj)
            if obj.fullyDefined
                filename = "CurveData/" + obj.id + ".csv";
                writematrix(obj.viMatrix, filename);
            else
                error('Cell must be fully defined');
            end
        end

        % Sets effective optical current given light intensity if cell
        % is fully defined
        function IoptEff = ComputeIoptEff(obj, lightIntensity)
            if obj.IsFullyDefined
                IoptEff = cosd(obj.theta) * cosd(obj.phi) * lightIntensity * obj.IoptMax;
            else
                error('Solar Cell is not fully defined');
            end
        end

    end
    
    methods (Static)

        function obj = CreateCell(id, varargin)
            obj = SolarCell;
            obj.id = id;
            obj.eta = [];
            obj.Is = [];
            obj.R = [];
            obj.IoptMax = [];
            obj.T = [];
            obj.theta = [];
            obj.phi = [];
            obj.fullyDefined = 0;
            obj.isSelected = 0;
            obj.parentModuleId = "";

            if nargin >= 5
                obj.eta = varargin{1};
                obj.Is = varargin{2};
                obj.R = varargin{3};
                obj.IoptMax = varargin{4};
            end
            if nargin >= 6
                obj.T = varargin{5};
            end
            if nargin == 8
                obj.theta = varargin{6};
                obj.phi = varargin{7};
                obj.fullyDefined = 1;
            end
        end

        % Convert absolute current into matrix index
        function idx = CurrentIndex(I)
            idx = int32((I + 1) * 100 + 1);
        end

        % Convert matrix index into absolute current
        function I = IndexCurrent(idx)
            I = (idx - 1) / 100 - 1;
        end
    
        % Convert absolute light intensity into matrix index
        function idx = liIndex(li)
            idx = int32(li * 100 + 1);
        end

    end

end