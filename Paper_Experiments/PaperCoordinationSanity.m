function check=PaperCoordinationSanity(coordinatedTC,fixedTC)
%PAPERCOORDINATIONSANITY Detect a heuristic violation of feasible-set nesting.
validateattributes(coordinatedTC,{'numeric'},{'scalar','positive','finite'});
validateattributes(fixedTC,{'numeric'},{'scalar','positive','finite'});
tolerance=1e-9*max([1,coordinatedTC,fixedTC]);
anomaly=coordinatedTC>fixedTC+tolerance;
status='no_detected_nesting_violation';
if anomaly, status='heuristic_search_insufficiency'; end
check=struct('CoordinatedTC',coordinatedTC,'FixedTC',fixedTC, ...
    'CostDifference',fixedTC-coordinatedTC, ...
    'SavingPercent',100*(fixedTC-coordinatedTC)/fixedTC, ...
    'Tolerance',tolerance,'IsAnomaly',anomaly,'Status',status);
end
