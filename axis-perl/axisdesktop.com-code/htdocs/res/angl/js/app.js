
var app = angular.module('app',['ngRoute']);

app.config(function($routeProvider){
$routeProvider
//default page
.when('/',{
templateUrl : 'pages/homepage.html',
controller : 'Homepage'
})
//about page
.when('/about',{
templateUrl : 'pages/about.html',
controller : 'About'
})
//date page
.when('/date',{
templateUrl : 'pages/date.html',
controller : 'Date'
});
});