%% SolarCell Class
% Defines a single solar cell
% Stores IV characteristics of cell in a matrix

classdef SolarCell < handle

    properties
        
        id uint32       % Identifier for cell object
        name = ""       % So Cluster knows this is SolarCell

        eta             % Ideality factor
        Is              % Reverse-bias saturation current
        R               % Series resistance
        IoptMax         % Optical current in full light
        T               % Cell temperature
        theta           % Pitch angle (0 when flat)
        phi             % Roll angle (0 when flat)

        parentId                % ID of module cell belongs to
        fullyDefined = 0        % All parameters are defined
        viMatrix                % VI Matrix for storing VI curve

    end

    methods

        % Check if fully defined every time parameter is set
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
            obj.parentId = 0;

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