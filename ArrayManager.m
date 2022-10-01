classdef ArrayManager < handle
    properties

        numSelectedCells = 0                % Number of cells currently selected
        cellSelectionList = zeros(257,1)    % Vector containing selected status of cells
        activeCellNum = 1                   % Index of most recently selected cell
        numCells = 257
        numModules = 0
        numSubArrays = 0
        cellList SolarCell      % Array of 257 SolarCell objects
        moduleList
        subArrayList
        moduleIdxList           % Map containing Module names and indices
        subArrayIdxList         % Map containing SubArray names indices

        ColorOrder = {'#D95319', '#EDB120', '#7E2F8E', '#77AC30', '#4DBEEE', '#A2142F'}
    end

    methods
        
        function SelectCell(obj, cellNum)
            obj.numSelectedCells = obj.numSelectedCells + 1;
            obj.cellSelectionList(cellNum) = 1;
            obj.activeCellNum = cellNum;
        end

        function DeselectCell(obj, cellNum)
            obj.numSelectedCells = obj.numSelectedCells - 1;
            obj.cellSelectionList(cellNum) = 0;
            obj.activeCellNum = find(obj.cellSelectionList==1,1);
        end

        function DefCellGlobalParams(obj, eta, Is, Rs, IoptMax, T)
            for i = 1:257   % Loop through cell indices
                obj.cellList(i).eta = eta;
                obj.cellList(i).Is = Is;
                obj.cellList(i).R = Rs;
                obj.cellList(i).IoptMax = IoptMax;
                obj.cellList(i).T = T;
            end
        end

        function DefCellLocalParams(obj, theta, phi)
            for i = 1:257   % Loop through cell indices
                if obj.cellSelectionList(i) == 1    % If cell at index is selected
                    obj.cellList(i).theta = theta;
                    obj.cellList(i).phi = phi;
                end
            end
        end

        function AddModule(obj, name)
            obj.numModules = obj.numModules + 1;
            obj.moduleList(obj.numModules) = Module.CreateModule(name);
        end

        function RemoveModule(obj, name)
            obj.numModules = obj.numModules - 1;
            % Insert null at removed module location
            obj.moduleList(obj.moduleIdxList(name)) = [];
            % Remove module name idx pair
            obj.moduleIdxList.remove(name);
        end

        function AddCellsToModule(obj, moduleName)
            for i = 1:257   % Loop through cell indices
                if obj.cellSelectionList(i) == 1    % If cell at index is selected
                    obj.moduleList(obj.moduleIdxList(moduleName)).AddCell(obj.cellList(i));
                end
            end
        end
    end
    
    methods (Static)

        % Constructor function
        function obj = CreateArrayManager()
            obj = ArrayManager;

            % Create 257 blank SolarCell objects
            for i = 1:257
                obj.cellList(i) = SolarCell.CreateCell(i);
            end
            % Create module and subarray index maps
            obj.moduleIdxList = containers.Map('KeyType','string','ValueType','uint32');
            obj.subArrayIdxList = containers.Map('KeyType','string','ValueType','uint32');
        
        end

    end
end