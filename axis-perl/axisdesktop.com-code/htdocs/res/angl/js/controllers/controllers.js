app.controller('Homepage',['$scope',function($scope){
$scope.homepage = "Homepage";
}]);
app.controller('About',['$scope', function($scope){
$scope.about = "Lorem ipsum...";
}]);
app.controller('Date',['$scope', function($scope) {
$scope.now = new Date();
}]);