%% Module Class
% Defines a group of series connected solar cells with bypass diode in
% parallel (modelled as ideal diode)

classdef Module < handle

    properties
        id                      % Module identifier
        cellList SolarCell      % Vector containing SolarCell objects
        numCells                % Number of objects in CellList
        shadeList               % Vector containing cell shade levels
        bypassPresent           % 1 if there is a bypass diode present

        viMatrix                % VI Matrix for storing VI curve
    end

    methods

        % Appends cell to end of cellList
        function AddCell(obj, cell)
            obj.numCells = obj.numCells + 1;
            obj.cellList(obj.numCells) = cell;
            obj.GenerateMatrix;
        end

        % Remove cell from end of cellList
        function RemoveCell(obj, idx)
            obj.cellList(idx) = [];
            obj.numCells = obj.numCells - 1;
            obj.GenerateMatrix;
        end

        % Setter function for bypass diode will re-generate matrix
        function set.bypassPresent(obj, bypassPresent)
            obj.bypassPresent = bypassPresent;
            obj.GenerateMatrix;
        end

        % Import VI matrix from file
        function ImportMatrix(obj, filename)
            obj.viMatrix = readmatrix("CurveData/" + filename);
        end

        % Returns cell current given voltage and light intensity
        function I = GetCurrent(obj, V, li)
            [~, idx] = min(abs(obj.viMatrix(obj.liIndex(li), :) - V));
            I = obj.IndexCurrent(idx);
        end

        % Returns cell voltage given current and light intensity
        function V = GetVoltage(obj, I, li)
            V = obj.viMatrix(obj.liIndex(li), obj.CurrentIndex(I));
        end

        % Returns open-circuit voltage based on light intensity
        function Voc = GetVoc(obj, li)
                Voc = obj.GetVoltage(0, li);
        end

        % Returns short-circuit current based on light intensity
        function Isc = GetIsc(obj, li)
            Isc = obj.GetCurrent(0, li);
        end

        % Returns power given voltage and light intensity
        function P = GetPowerV(obj, V, li)
            P = V .* obj.GetCurrent(V, li);
            P = P .* ~(isinf(P));
        end

        % Returns power given current and light intensity
        function P = GetPowerI(obj, I, li)
            P = I .* obj.GetVoltage(I, li);
            P = P .* ~(isinf(P));
        end

        % Returns electrical parameters at the maximum power point
        function [Vmpp, Impp, Pmpp] = GetMPP(obj, li)
            Impp = fminbnd(@(I)obj.GetPowerI(I, li) * (-1), 0, obj.cellList(1).IoptMax);
            Vmpp = obj.GetVoltage(Impp, li);
            Pmpp = Impp * Vmpp;
        end

        % Plot VI curve
        function PlotVI(obj, li)
            I = linspace(-1, 10, 1101);
            y = obj.viMatrix(obj.liIndex(li), :);

            hold on
            title('VI Characteristics of ' + obj.id)
            plot(I, y);
            plot([0 0], ylim, 'k-')         % plot y-axis
            plot(xlim, [0 0], 'k-')         % plot x-axis
            xlabel('Currnet (A)')
            ylabel('Voltage (V)')
            hold off
        end

        % Plot IV curve
        function PlotIV(obj, li)
            V = obj.viMatrix(obj.liIndex(li), :);
            I = linspace(-1, 10, 1101);

            hold on
            title('IV Characteristics of ' + obj.id)
            plot(V, I);
            plot([0 0], ylim, 'k-')         % plot y-axis
            plot(xlim, [0 0], 'k-')         % plot x-axis
            xlabel('Voltage (V)')
            ylabel('Currnet (A)')
            hold off
        end

        % Plot MPP curve with IV curve
        function PlotMPP(obj, li)
            V = obj.viMatrix(obj.liIndex(li), :);
            I = linspace(-1, 10, 1101);
            P = obj.GetPowerI(I, li);
            [Vmpp, Impp, ~] = obj.GetMPP(li);

            hold on
            title('IV Characteristics of ' + obj.id)

            yyaxis left
            plot(V, I);                     % Plot current as a function of voltage
            plot([Vmpp Vmpp], ylim, 'r-')   % plot MPP voltage
            plot(xlim, [Impp Impp], 'r-')   % plot MPP current
            plot([0 0], ylim, 'k-')         % plot y-axis
            plot(xlim, [0 0], 'k-')         % plot x-axis
            xlabel('Voltage (V)')
            ylabel('Currnet (A)')

            yyaxis right
            plot(V, P)                      % plot power as a function of voltage
            ylabel('Power (W)')
            hold off
        end

    end

    methods (Access = private)

        % Generate VI matrix for module
        function GenerateMatrix(obj)
            if obj.numCells > 0
                obj.viMatrix = zeros(size(obj.cellList(1).viMatrix));
                for i = 1:obj.numCells              % Sum the matricies of individual cells
                    if obj.cellList(i).fullyDefined == 1
                        obj.viMatrix = obj.viMatrix + obj.cellList(i).viMatrix;
                    else
                        error('Cells must be fully defined');
                    end
                end

                if obj.bypassPresent                % Add parallel ideal diode
                    obj.viMatrix = obj.viMatrix .* (obj.viMatrix >= 0);
                    obj.viMatrix = obj.viMatrix .* ~isinf(obj.viMatrix);
                end

                filename = "CurveData/" + obj.id + ".csv";
                writematrix(obj.viMatrix, filename);
            end
        end
    end

    methods (Static)

        % Constructor function
        function obj = CreateModule(id, varargin)
            obj = Module;
            obj.id = id;
            obj.numCells = nargin - 1;
            obj.shadeList = [];
            obj.bypassPresent = 0;
            for i = 1:(nargin - 1)
                obj.cellList(i) = varargin{i};
            end
            obj.GenerateMatrix;
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