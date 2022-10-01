%% SolarCell Class
% Defines a single solar cell
% Stores IV characteristics of cell in a vector called viVector
%
% Cell is initialized by cell = SolarCell.CreateCell(id)

classdef SolarCell < handle

    properties

        id uint32           % Unique for each cell on car
        name = ""           % Identifies SolarCell as base object
        parentId = 0        % ID of module cell belongs to

        eta = []            % Ideality factor
        Is = []             % Reverse-bias saturation current
        R = []              % Series resistance
        IoptMax = []        % Optical current in full light
        T = []              % Cell temperature
        theta = []          % Pitch angle (0 when flat)
        phi= []             % Roll angle (0 when flat)

        viVector            % VI vector for storing IV curve
        fullyDefined = 0    % All parameters have a value
    end

    methods
        
        % Check if cell is fully defined every time parameter is set
        function set.eta(obj, eta)
            obj.eta = eta;
            obj.CheckFullyDefined;
        end
        function set.Is(obj, Is)
            obj.Is = Is;
            obj.CheckFullyDefined;
        end
        function set.R(obj, R)
            obj.R = R;
            obj.CheckFullyDefined;
        end
        function set.T(obj, T)
            obj.T = T;
            obj.CheckFullyDefined;
        end
        function set.IoptMax(obj, IoptMax)
            obj.IoptMax = IoptMax;
            obj.CheckFullyDefined;
        end
        function set.theta(obj, theta)
            obj.theta = theta;
            obj.CheckFullyDefined;
        end
        function set.phi(obj, phi)
            obj.phi = phi;
            obj.CheckFullyDefined;
        end
        
        % Generates VI Vector based on light intensity, sun zenith, and
        % sun azimuth
        function GenerateCurve(obj, li, zen, azm)
            if obj.fullyDefined
                % Compute effective light intensity based on sun angles
                sunVector = [sind(zen)*cosd(azm) sind(zen)*sind(azm) cosd(zen)];
                sunVectorUnit = sunVector / norm(sunVector);
                cellNormal = [-sind(obj.theta) sind(obj.phi) cosd(obj.theta)];
                cellNormalUnit = cellNormal / norm(cellNormal);
                cosIncidence = dot(sunVectorUnit, cellNormalUnit);
                effLi = li * cosIncidence;

                % Compute effective optical current based on effective
                % light intensity
                IoptEff = obj.IoptMax * effLi;

                % Generate VI vector
                Id = linspace(-1, 10, 11001);        % Current points for horizontal axis
                multiplier = obj.eta * (obj.T / 11586);
                log_term = log(((IoptEff - Id) / obj.Is) + 1);
                series_r_drop = Id * obj.R;
                obj.viVector = multiplier * log_term - series_r_drop;

                % Handle undefined logs
                obj.viVector = obj.viVector ./ (imag(log_term) == 0);
                obj.viVector = real(obj.viVector);
            else
                error('Cell must by fully defined');
            end
        end

        % Returns cell current given voltage
        function I = GetCurrent(obj, V)
            if obj.fullyDefined
                [~, idx] = min(abs(obj.viVector - V));
                I = obj.IdxtoI(idx);
            else
                error('Cell must be fully defined');
            end
        end

        % Returns cell voltage given current
        function V = GetVoltage(obj, I)
            if obj.fullyDefined
                idx = obj.ItoIdx(I);
                V = obj.viVector(idx);
            else
                error('Cell must be fully defined');
            end
        end

        % Returns open-circuit voltage
        function Voc = GetVoc(obj)
            if obj.fullyDefined
                Voc = obj.GetVoltage(0);
            else
                error('Cell must be fully defined');
            end
        end

        % Returns short-circuit current
        function Isc = GetIsc(obj)
            if obj.fullyDefined
                Isc = obj.GetCurrent(0);
            else
                error('Cell must be fully defined');
            end
        end

        % Returns power given voltage
        function P = GetPowerV(obj, V)
            if obj.fullyDefined
                P = V .* obj.GetCurrent(V);
                P = P .* ~(isinf(P));
            else
                error('Cell must be fully defined');
            end
        end

        % Returns power given current
        function P = GetPowerI(obj, I)
            if obj.fullyDefined
                P = I .* obj.GetVoltage(I);
                P = P .* ~(isinf(P));
            else
                error('Cell must be fully defined');
            end
        end

        % Returns electrical parameters at the maximum power point
        function [Vmpp, Impp, Pmpp] = GetMPP(obj)
            if obj.fullyDefined
                Impp = fminbnd(@(I)obj.GetPowerI(I) * (-1), 0, obj.IoptMax);
                Vmpp = obj.GetVoltage(Impp);
                Pmpp = Impp * Vmpp;
            else
                error('Cell must be fully defined');
            end
        end

    end

    methods (Access = private)

        % Sees if all parameters are populated and sets fullyDefined
        function CheckFullyDefined(obj)
            if ~isempty(obj.eta) && ~isempty(obj.Is) && ~isempty(obj.IoptMax) &&...
                    ~isempty(obj.T) && ~isempty(obj.theta) && ~isempty(obj.phi)
                obj.fullyDefined = 1;
            else
                obj.fullyDefined = 0;
            end
        end

    end

    methods (Static)
        
        % Object constructor function
        function obj = CreateCell(id)
            obj = SolarCell;
            obj.id = id;
        end

        % Convert current (A) to index
        function idx = ItoIdx(I)
            idx = floor((I + 1) * 1000 + 1);
        end

        % Convert index to current (A)
        function I = IdxtoI(idx)
            I = (idx - 1) / 1000 - 1;
        end

    end

end